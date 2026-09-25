// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : tb_crc16_modbus.v
// Module  : tb_crc16_modbus
// Created : 2026-05-25
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_crc16_modbus;
    reg clk = 0;
    always #10 clk = ~clk;
    reg reset = 1;
    reg crc_din_vld = 0;
    reg [7:0] crc_din = 0;
    reg crc_done = 0;
    wire [15:0] crc_dout_f;
    integer i;

    crc16_d8 dut (
        .clk(clk), .reset(reset), .crc_din_vld(crc_din_vld),
        .crc_din(crc_din), .crc_dout_f(crc_dout_f), .crc_done(crc_done)
    );

    initial begin
        repeat (3) @(negedge clk);
        reset = 0;
        for (i = 0; i < 9; i = i + 1) begin
            crc_din_vld = 1;
            crc_din = 8'h31 + i;
            @(negedge clk);
        end
        crc_din_vld = 0;
        #1;
        if (crc_dout_f !== 16'h4B37)
            $fatal(1, "CRC16 mismatch: got %h, expected 4B37", crc_dout_f);
        crc_done = 1;
        @(negedge clk);
        crc_done = 0;
        #1;
        if (crc_dout_f !== 16'hFFFF)
            $fatal(1, "CRC16 reset mismatch: %h", crc_dout_f);
        $display("PASS: CRC16 = 4B37 for 123456789, reset = FFFF");
        $finish;
    end
endmodule
