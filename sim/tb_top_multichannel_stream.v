// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : tb_top_multichannel_stream.v
// Module  : tb_top_multichannel_stream
// Created : 2026-06-27
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
module tb_top_multichannel_stream;
    localparam integer BIT_NS=8680;
    reg clk=0, rst_n=0, uart_rxd=1;
    always #10 clk=~clk;
    wire uart_txd, led0;
    tri1 iic_scl, iic_sda;
    reg [7:0] got[0:127];
    reg [7:0] b;
    reg [15:0] crc;
    integer n=0, i, j, k;
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
    task send_command;
        input [7:0] kind, crc_lo, crc_hi;
        begin
            send_byte(8'hA5); send_byte(8'h5A); send_byte(kind);
            send_byte(0); send_byte(0);
            send_byte(crc_lo); send_byte(crc_hi);
        end
    endtask
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
    always begin
        @(negedge uart_txd); #(BIT_NS+BIT_NS/2);
        b=0;
        for(i=0;i<8;i=i+1) begin b[i]=uart_txd; #(BIT_NS); end
        if(uart_txd !== 1'b1) $fatal(1,"stop bit missing");
        got[n]=b; n=n+1;
    end
    initial begin
        #200; rst_n=1; #1000;
        send_command(8'h03,8'h00,8'h00);
        #1000000;
        if(n!=0) $fatal(1,"invalid START CRC was accepted");
        send_command(8'h03,8'h81,8'hC0);
        wait(n>=8);
        if(got[0]!==8'hA5 || got[1]!==8'h5A || got[2]!==8'h83 ||
           got[3]!==0 || got[4]!==1 || got[5]!==1)
            $fatal(1,"START ACK wrong");
        crc=16'hFFFF;
        for(j=2;j<=5;j=j+1) crc=crc_step(crc,got[j]);
        if(got[6]!==crc[7:0] || got[7]!==crc[15:8])
            $fatal(1,"START ACK CRC wrong");
        wait(n>=49);
        if(got[8]!==8'hA5 || got[9]!==8'h5A || got[10]!==8'h91 ||
           got[11]!==0 || got[12]!==34 || got[13]!==0 || got[14]!==0)
            $fatal(1,"batch header wrong");
        for(j=0;j<16;j=j+1) begin
            case (j%4)
                0: if({got[15+j*2],got[16+j*2]}!==16'h0977)
                    $fatal(1,"temperature record %0d wrong",j);
                1: if({got[15+j*2],got[16+j*2]}!==16'h4555)
                    $fatal(1,"VCCINT record %0d wrong",j);
                2: if({got[15+j*2],got[16+j*2]}!==16'h8999)
                    $fatal(1,"VCCAUX record %0d wrong",j);
                3: if({got[15+j*2],got[16+j*2]}!==16'hC556)
                    $fatal(1,"VCCBRAM record %0d wrong",j);
            endcase
        end
        crc=16'hFFFF;
        for(j=10;j<=46;j=j+1) crc=crc_step(crc,got[j]);
        if(got[47]!==crc[7:0] || got[48]!==crc[15:8])
            $fatal(1,"batch CRC wrong: got %02x %02x expected %04x",
                got[47],got[48],crc);
        wait(n>=90);
        if(got[49]!==8'hA5 || got[50]!==8'h5A || got[51]!==8'h91 ||
           got[52]!==1 || got[53]!==34)
            $fatal(1,"second batch sequence wrong");
        for(j=0;j<16;j=j+1) begin
            case (j%4)
                0: if({got[56+j*2],got[57+j*2]}!==16'h0977)
                    $fatal(1,"second temperature record %0d wrong",j);
                1: if({got[56+j*2],got[57+j*2]}!==16'h4555)
                    $fatal(1,"second VCCINT record %0d wrong",j);
                2: if({got[56+j*2],got[57+j*2]}!==16'h8999)
                    $fatal(1,"second VCCAUX record %0d wrong",j);
                3: if({got[56+j*2],got[57+j*2]}!==16'hC556)
                    $fatal(1,"second VCCBRAM record %0d wrong",j);
            endcase
        end
        crc=16'hFFFF;
        for(j=51;j<=87;j=j+1) crc=crc_step(crc,got[j]);
        if(got[88]!==crc[7:0] || got[89]!==crc[15:8])
            $fatal(1,"second batch CRC wrong");
        send_command(8'h04,8'h30,8'h01);
        wait(n>=98);
        if(got[92]!==8'h84 || got[94]!==1 || got[95]!==0)
            $fatal(1,"STOP ACK wrong");
        crc=16'hFFFF;
        for(j=92;j<=95;j=j+1) crc=crc_step(crc,got[j]);
        if(got[96]!==crc[7:0] || got[97]!==crc[15:8])
            $fatal(1,"STOP ACK CRC wrong");
        #2000000;
        if(n!=98) $fatal(1,"unexpected output after STOP");
        $display("PASS: bad CRC rejected, START, two 16-sample batches, CRC, UART, STOP");
        $finish;
    end
    initial begin #50000000; $fatal(1,"stream timeout n=%0d",n); end
endmodule
