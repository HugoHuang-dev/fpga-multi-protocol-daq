// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : xadc_multichannel.v
// Module  : xadc_multichannel
// Created : 2026-06-27
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// Read the four on-chip XADC status channels. No external analog I/O is used.
// DRP addresses 00h/01h/02h/06h are temperature/VCCINT/VCCAUX/VCCBRAM.
module xadc_multichannel (
    input wire clk,
    input wire rst,
    output reg [11:0] temperature,
    output reg [11:0] vccint,
    output reg [11:0] vccaux,
    output reg [11:0] vccbram,
    output reg [3:0] valid_mask
);
    wire eoc, drdy;
    wire [4:0] channel;
    wire [15:0] drp_data;
    reg [4:0] requested_channel;

    // UG480's internal-sensor sequencer setting; external channels disabled.
    XADC #(
        .INIT_40(16'h9000),
        .INIT_41(16'h2EF0),
        .INIT_42(16'h0400),
        .INIT_48(16'h4701),
        .INIT_49(16'h0000),
        .SIM_DEVICE("7SERIES")
    ) xadc_inst (
        .DCLK(clk), .DADDR({2'b00, channel}), .DEN(eoc),
        .DI(16'h0000), .DWE(1'b0), .RESET(rst),
        .CONVST(1'b0), .CONVSTCLK(1'b0),
        .VAUXP(16'h0000), .VAUXN(16'h0000),
        .VP(1'b0), .VN(1'b0),
        .DO(drp_data), .DRDY(drdy), .EOC(eoc), .CHANNEL(channel),
        .ALM(), .BUSY(), .EOS(), .JTAGBUSY(), .JTAGLOCKED(),
        .JTAGMODIFIED(), .OT(), .MUXADDR()
    );

    always @(posedge clk) begin
        if (rst) begin
            requested_channel <= 0;
            temperature <= 0;
            vccint <= 0;
            vccaux <= 0;
            vccbram <= 0;
            valid_mask <= 0;
        end else begin
            if (eoc) requested_channel <= channel;
            if (drdy) begin
                case (requested_channel)
                    5'h00: begin temperature <= drp_data[15:4]; valid_mask[0] <= 1; end
                    5'h01: begin vccint <= drp_data[15:4]; valid_mask[1] <= 1; end
                    5'h02: begin vccaux <= drp_data[15:4]; valid_mask[2] <= 1; end
                    5'h06: begin vccbram <= drp_data[15:4]; valid_mask[3] <= 1; end
                    default: ;
                endcase
            end
        end
    end
endmodule
