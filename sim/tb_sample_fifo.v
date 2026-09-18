// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : tb_sample_fifo.v
// Module  : tb_sample_fifo
// Created : 2026-06-01
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
module tb_sample_fifo;
    reg clk=0, rst=1, clear=0, wr_en=0, rd_en=0;
    reg [15:0] wr_data=0;
    wire [15:0] rd_data;
    wire full, empty;
    wire [6:0] count;
    integer i;
    always #10 clk=~clk;
    sample_fifo dut(.clk(clk), .rst(rst), .clear(clear),
        .wr_en(wr_en), .wr_data(wr_data), .rd_en(rd_en),
        .rd_data(rd_data), .full(full), .empty(empty), .count(count));
    initial begin
        @(negedge clk); rst=0;
        for(i=0;i<64;i=i+1) begin
            @(negedge clk); wr_data=i; wr_en=1;
        end
        @(negedge clk); wr_en=0;
        if(!full || count!==64) $fatal(1,"full count wrong");
        @(negedge clk); wr_en=1; wr_data=16'hDEAD;
        @(negedge clk); wr_en=0;
        if(count!==64) $fatal(1,"full FIFO accepted extra sample");
        for(i=0;i<64;i=i+1) begin
            @(negedge clk);
            if(rd_data!==i) $fatal(1,"sample %0d wrong: %h",i,rd_data);
            rd_en=1;
        end
        @(negedge clk); rd_en=0;
        if(!empty || count!==0) $fatal(1,"empty count wrong");
        @(negedge clk); wr_data=16'h1234; wr_en=1;
        @(negedge clk); wr_en=0;
        if(rd_data!==16'h1234) $fatal(1,"wraparound sample wrong");
        @(negedge clk); clear=1;
        @(negedge clk); clear=0;
        if(!empty || count!==0) $fatal(1,"clear failed");
        $display("PASS: acquisition FIFO 64 entries, full guard, order, wrap, clear");
        $finish;
    end
endmodule
