// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : xadc_temp_stub.v
// Module  : xadc_temp
// Created : 2026-05-12
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// Simulation stand-in. Hardware synthesis uses rtl/xadc_temp.v instead.
module xadc_temp (
    input wire clk,
    input wire rst,
    output reg [11:0] sample,
    output reg sample_valid
);
    reg [7:0] startup_count;
    always @(posedge clk) begin
        if (rst) begin
            startup_count <= 0;
            sample <= 0;
            sample_valid <= 0;
        end else if (startup_count != 100) startup_count <= startup_count + 1'b1;
        else begin
            sample <= 12'h977;
            sample_valid <= 1;
        end
    end
endmodule
