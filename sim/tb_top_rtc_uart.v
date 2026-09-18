// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : tb_top_rtc_uart.v
// Module  : tb_top_rtc_uart
// Created : 2026-07-05
// Revised : 2026-09-18
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
module tb_top_rtc_uart;
    localparam integer BIT_NS=8680;
    reg clk=0, rst_n=0, uart_rxd=1;
    always #10 clk=~clk;
    wire uart_txd, led0;
    tri1 iic_scl, iic_sda;
    reg slave_low=0;
    assign iic_sda=slave_low ? 1'b0 : 1'bz;
    reg [55:0] rtc_memory=0;
    reg [7:0] got[0:127];
    reg [7:0] rx_byte, bus_byte;
    reg [15:0] check_crc;
    integer n=0, i, k, operations=0;
    top_rtc #(.RTC_POLL_CYCLES(200000)) dut(.clkin_50m(clk), .rst_n(rst_n), .uart_rxd(uart_rxd),
        .uart_txd(uart_txd), .iic_scl(iic_scl), .iic_sda(iic_sda), .led0(led0));
    function [15:0] crc_step;
        input [15:0] old_crc;
        input [7:0] data;
        reg [15:0] value;
        integer bit_no;
        begin
            value=old_crc ^ data;
            for(bit_no=0;bit_no<8;bit_no=bit_no+1)
                value=value[0] ? (value>>1)^16'hA001 : value>>1;
            crc_step=value;
        end
    endfunction

    task send_byte;
        input [7:0] value;
        integer bit_no;
        begin
            @(negedge clk); uart_rxd=0; #(BIT_NS);
            for(bit_no=0;bit_no<8;bit_no=bit_no+1) begin
                uart_rxd=value[bit_no]; #(BIT_NS);
            end
            uart_rxd=1; #(BIT_NS);
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
        integer j;
        begin
            value=0;
            for(j=7;j>=0;j=j-1) begin @(posedge iic_scl); value[j]=iic_sda; end
        end
    endtask
    task ack_iic_byte;
        begin
            @(negedge iic_scl); slave_low=1;
            @(posedge iic_scl);
            @(negedge iic_scl); slave_low=0;
        end
    endtask
    task send_iic_byte;
        input [7:0] value;
        input last;
        integer j;
        begin
            for(j=7;j>=0;j=j-1) begin
                slave_low=!value[j];
                @(posedge iic_scl); @(negedge iic_scl);
            end
            slave_low=0;
            @(posedge iic_scl);
            if(iic_sda !== (last ? 1'b1 : 1'b0))
                $fatal(1,"RTC ACK/NACK wrong");
            if(!last) @(negedge iic_scl);
        end
    endtask
    always begin
        wait(rst_n && !dut.rst);
        @(negedge iic_sda);
        if(iic_scl!==1'b1) $fatal(1,"I2C START invalid");
        get_iic_byte(bus_byte);
        if(bus_byte!==8'hA2) $fatal(1,"RTC write address %h",bus_byte);
        ack_iic_byte();
        get_iic_byte(bus_byte);
        if(bus_byte!==8'h02) $fatal(1,"RTC pointer %h",bus_byte);
        ack_iic_byte();
        if(dut.rtc_bus.do_write) begin
            for(k=0;k<7;k=k+1) begin
                get_iic_byte(bus_byte);
                rtc_memory[55-k*8 -:8]=bus_byte;
                ack_iic_byte();
            end
        end else begin
            @(negedge iic_sda);
            if(iic_scl!==1'b1) $fatal(1,"repeated START invalid");
            get_iic_byte(bus_byte);
            if(bus_byte!==8'hA3) $fatal(1,"RTC read address %h",bus_byte);
            ack_iic_byte();
            for(k=0;k<7;k=k+1)
                send_iic_byte(rtc_memory[55-k*8 -:8],k==6);
        end
        @(posedge iic_sda);
        if(iic_scl!==1'b1) $fatal(1,"I2C STOP invalid");
        operations=operations+1;
    end

    initial begin
        #200; rst_n=1; #1000;
        // Host-generated SET: 2026-09-17 19:25:34, weekday=3.
        send_byte('hA5); send_byte('h5A); send_byte('h08);
        send_byte(0); send_byte(7); send_byte('h34); send_byte('h25);
        send_byte('h19); send_byte('h17); send_byte('h03);
        send_byte('h09); send_byte('h26); send_byte('hAD); send_byte('h01);
        wait(n>=8);
        if(got[2]!==8'h88 || got[4]!==1 || got[5]!==0)
            $fatal(1,"RTC set reply wrong");
        if(rtc_memory!==56'h34251917030926)
            $fatal(1,"RTC write memory wrong: %h",rtc_memory);
        send_byte('hA5); send_byte('h5A); send_byte('h07);
        send_byte(1); send_byte(0); send_byte('hC1); send_byte('h91);
        wait(n>=23);
        if(got[8]!==8'hA5 || got[9]!==8'h5A || got[10]!==8'h87 ||
           got[11]!==1 || got[12]!==8 || got[14]!==8'h34 ||
           got[15]!==8'h25 || got[16]!==8'h19 || got[17]!==8'h17 ||
           got[18]!==8'h03 || got[19]!==8'h09 || got[20]!==8'h26)
            $fatal(1,"RTC read reply wrong");
        check_crc=16'hFFFF;
        for(k=10;k<=20;k=k+1) check_crc=crc_step(check_crc,got[k]);
        if(got[21]!==check_crc[7:0] || got[22]!==check_crc[15:8])
            $fatal(1,"RTC read CRC wrong");
        if(operations!=2) $fatal(1,"RTC operation count %0d",operations);
        send_byte('hA5); send_byte('h5A); send_byte('h03);
        send_byte(0); send_byte(0); send_byte('h81); send_byte('hC0);
        wait(n>=31);
        if(got[25]!==8'h83) $fatal(1,"START reply missing");
        wait(n>=46);
        if(got[31]!==8'hA5 || got[32]!==8'h5A || got[33]!==8'h92 ||
           got[35]!==8 || got[37]!==8'h34 || got[38]!==8'h25 ||
           got[39]!==8'h19 || got[40]!==8'h17 || got[41]!==8'h03 ||
           got[42]!==8'h09 || got[43]!==8'h26)
            $fatal(1,"periodic RTC marker missing or wrong");
        check_crc=16'hFFFF;
        for(k=33;k<=43;k=k+1) check_crc=crc_step(check_crc,got[k]);
        if(got[44]!==check_crc[7:0] || got[45]!==check_crc[15:8])
            $fatal(1,"periodic RTC marker CRC wrong");
        if(operations!=3) $fatal(1,"periodic RTC poll missing");
        $display("PASS: UART RTC set/read, shared I2C, periodic time marker");
        $finish;
    end
    initial begin #50000000; $fatal(1,"RTC top timeout n=%0d",n); end
endmodule
