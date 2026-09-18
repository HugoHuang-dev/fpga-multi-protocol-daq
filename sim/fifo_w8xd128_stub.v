// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : fifo_w8xd128_stub.v
// Module  : fifo_w8xd128
// Created : 2026-05-18
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// Behavioral first-word-fall-through model of the course FIFO Generator IP.
// The Vivado project uses ip/fifo_w8xd128.xci instead.
module fifo_w8xd128 (
    input wire clk,
    input wire srst,
    input wire [7:0] din,
    input wire wr_en,
    input wire rd_en,
    output wire [7:0] dout,
    output wire full,
    output wire empty,
    output wire [7:0] data_count
);
    reg [7:0] mem [0:127];
    reg [6:0] wr_ptr;
    reg [6:0] rd_ptr;
    reg [7:0] count;
    wire push = wr_en && !full;
    wire pop = rd_en && !empty;

    assign dout = mem[rd_ptr];
    assign full = (count == 128);
    assign empty = (count == 0);
    assign data_count = count;

    always @(posedge clk) begin
        if (srst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
        end else begin
            if (push) begin
                mem[wr_ptr] <= din;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (pop) rd_ptr <= rd_ptr + 1'b1;
            case ({push, pop})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule
