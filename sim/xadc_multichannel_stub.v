// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : xadc_multichannel_stub.v
// Module  : xadc_multichannel
// Created : 2026-06-27
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// Stable sensor readings for system-level UART simulation only.
module xadc_multichannel (
    input wire clk,
    input wire rst,
    output reg [11:0] temperature,
    output reg [11:0] vccint,
    output reg [11:0] vccaux,
    output reg [11:0] vccbram,
    output reg [3:0] valid_mask
);
    reg [7:0] startup_count;
    always @(posedge clk) begin
        if (rst) begin
            startup_count <= 0;
            temperature <= 0;
            vccint <= 0;
            vccaux <= 0;
            vccbram <= 0;
            valid_mask <= 0;
        end else if (startup_count != 100) startup_count <= startup_count + 1'b1;
        else begin
            temperature <= 12'h977;
            vccint <= 12'h555;
            vccaux <= 12'h999;
            vccbram <= 12'h556;
            valid_mask <= 4'hF;
        end
    end
endmodule
