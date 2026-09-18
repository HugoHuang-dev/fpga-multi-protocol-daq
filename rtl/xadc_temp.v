// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : xadc_temp.v
// Module  : xadc_temp
// Created : 2026-05-12
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// XADC on-chip temperature sensor. The top 12 bits of DRP register 00h
// contain the raw conversion result. No external analog pins are required.
module xadc_temp (
    input wire clk,
    input wire rst,
    output reg [11:0] sample,
    output reg sample_valid
);
    wire eoc;
    wire drdy;
    wire [15:0] drp_data;

    XADC #(
        .INIT_40(16'h0000),
        .INIT_41(16'h21A0),
        .INIT_42(16'h0400),
        .INIT_48(16'h0100), // temperature channel
        .INIT_49(16'h0000), // no external auxiliary channels
        .SIM_DEVICE("7SERIES")
    ) xadc_inst (
        .DCLK(clk),
        .DADDR(7'h00),
        .DEN(eoc),
        .DI(16'h0000),
        .DWE(1'b0),
        .RESET(rst),
        .CONVST(1'b0),
        .CONVSTCLK(1'b0),
        .VAUXP(16'h0000),
        .VAUXN(16'h0000),
        .VP(1'b0),
        .VN(1'b0),
        .DO(drp_data),
        .DRDY(drdy),
        .EOC(eoc),
        .ALM(), .BUSY(), .CHANNEL(), .EOS(),
        .JTAGBUSY(), .JTAGLOCKED(), .JTAGMODIFIED(),
        .OT(), .MUXADDR()
    );

    always @(posedge clk) begin
        if (rst) begin
            sample <= 0;
            sample_valid <= 0;
        end else if (drdy) begin
            sample <= drp_data[15:4];
            sample_valid <= 1;
        end
    end
endmodule
