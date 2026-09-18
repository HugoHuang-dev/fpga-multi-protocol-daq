// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : tb_top_multichannel_eeprom.v
// Module  : tb_top_multichannel_eeprom
// Created : 2026-06-27
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
module tb_top_multichannel_eeprom;
    localparam integer BIT_NS=8680;
    reg clk=0, rst_n=0, uart_rxd=1;
    always #10 clk=~clk;
    wire uart_txd, led0;
    tri1 iic_scl, iic_sda;
    reg slave_low=0;
    reg nack_next=0;
    assign iic_sda=slave_low ? 1'b0 : 1'bz;
    reg [7:0] memory_byte=8'h3C;
    reg [7:0] address_byte, high_byte, low_byte, data_byte;
    reg [7:0] got[0:127];
    reg [7:0] rx_byte;
    integer n=0, i, k, operations=0;
    top_multichannel dut(.clkin_50m(clk), .rst_n(rst_n),
        .uart_rxd(uart_rxd), .uart_txd(uart_txd),
        .iic_scl(iic_scl), .iic_sda(iic_sda), .led0(led0));
    task send_byte;
        input [7:0] v;
        integer bit_no;
        begin
            @(negedge clk); uart_rxd=0; #(BIT_NS);
            for(bit_no=0;bit_no<8;bit_no=bit_no+1) begin
                uart_rxd=v[bit_no]; #(BIT_NS);
            end
            uart_rxd=1; #(BIT_NS);
        end
    endtask
    task send_read;
        input [7:0] seq, crc_lo, crc_hi;
        begin
            send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h05);
            send_byte(seq); send_byte(2); send_byte(8'h1F); send_byte(8'hF0);
            send_byte(crc_lo); send_byte(crc_hi);
        end
    endtask
    task send_write;
        begin
            send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h06);
            send_byte(1); send_byte(3); send_byte(8'h1F); send_byte(8'hF0);
            send_byte(8'hA6); send_byte(8'hC8); send_byte(8'h45);
        end
    endtask
    always begin
        @(negedge uart_txd); #(BIT_NS+BIT_NS/2);
        rx_byte=0;
        for(i=0;i<8;i=i+1) begin rx_byte[i]=uart_txd; #(BIT_NS); end
        if(uart_txd!==1'b1) $fatal(1,"UART stop bit missing");
        got[n]=rx_byte; n=n+1;
    end
    task get_iic_byte;
        output reg [7:0] value;
        integer bit_no;
        begin
            value=0;
            for(bit_no=7;bit_no>=0;bit_no=bit_no-1) begin
                @(posedge iic_scl); value[bit_no]=iic_sda;
            end
        end
    endtask
    task ack_iic_byte;
        begin
            @(negedge iic_scl); slave_low=1;
            @(posedge iic_scl);
            @(negedge iic_scl); slave_low=0;
        end
    endtask
    always begin
        wait(rst_n && !dut.rst);
        @(negedge iic_sda);
        if(iic_scl!==1'b1) $fatal(1,"I2C START invalid");
        get_iic_byte(address_byte);
        if(address_byte!==8'hA0) $fatal(1,"I2C device address wrong");
        if(nack_next) nack_next=0;
        else begin
            ack_iic_byte();
            get_iic_byte(high_byte); ack_iic_byte();
            get_iic_byte(low_byte); ack_iic_byte();
            if({high_byte,low_byte}!==16'h1FF0) $fatal(1,"I2C word address wrong");
            if(dut.eeprom_bus.do_read) begin
                @(negedge iic_sda);
                if(iic_scl!==1'b1) $fatal(1,"repeated START invalid");
                get_iic_byte(address_byte);
                if(address_byte!==8'hA1) $fatal(1,"I2C read address wrong");
                ack_iic_byte();
                for(k=7;k>=0;k=k-1) begin
                    slave_low=!memory_byte[k];
                    @(posedge iic_scl);
                    @(negedge iic_scl);
                end
                slave_low=0;
                @(posedge iic_scl);
                if(iic_sda!==1'b1) $fatal(1,"read NACK missing");
            end else begin
                get_iic_byte(data_byte); ack_iic_byte();
                memory_byte=data_byte;
            end
        end
        begin : wait_stop
            forever begin
                @(posedge iic_sda);
                if(iic_scl===1'b1) disable wait_stop;
            end
        end
        operations=operations+1;
    end
    task check_frame;
        input integer offset;
        input [7:0] kind, seq, data, crc_lo, crc_hi;
        begin
            if(got[offset]!==8'hA5 || got[offset+1]!==8'h5A ||
               got[offset+2]!==kind || got[offset+3]!==seq ||
               got[offset+4]!==1 || got[offset+5]!==data ||
               got[offset+6]!==crc_lo || got[offset+7]!==crc_hi)
                $fatal(1,"reply mismatch at %0d",offset);
        end
    endtask
    initial begin
        #200; rst_n=1; #1000;
        send_read(0,8'h41,8'hB4);
        wait(n>=8); check_frame(0,8'h85,0,8'h3C,8'h28,8'hA9);
        send_write();
        wait(n>=16); check_frame(8,8'h86,1,0,8'h79,8'h3C);
        if(memory_byte!==8'hA6) $fatal(1,"EEPROM model write failed");
        send_read(2,8'h40,8'h0C);
        wait(n>=24); check_frame(16,8'h85,2,8'hA6,8'h09,8'h02);
        nack_next=1;
        send_read(3,8'h41,8'hF0);
        wait(n>=32); check_frame(24,8'hE1,3,1,8'h06,8'h48);
        // The old PING command must still work after EEPROM traffic.
        send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h01);
        send_byte(0); send_byte(0); send_byte(8'h20); send_byte(0);
        wait(n>=40); check_frame(32,8'h81,0,3,8'h69,8'h89);
        if(operations!=4) $fatal(1,"I2C operation count wrong");
        $display("PASS: UART/CRC -> EEPROM read/write/read, NACK error, PING retained");
        $finish;
    end
    initial begin #25000000; $fatal(1,"EEPROM top timeout n=%0d",n); end
endmodule
