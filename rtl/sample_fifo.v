// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : sample_fifo.v
// Module  : sample_fifo
// Created : 2026-06-01
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// Separate acquisition FIFO: 64 entries of 16-bit sampled data.
// One 50 MHz clock domain; the UART byte FIFO remains uart_send_fifo.v.
module sample_fifo (
    input wire clk,
    input wire rst,
    input wire clear,
    input wire wr_en,
    input wire [15:0] wr_data,
    input wire rd_en,
    output wire [15:0] rd_data,
    output wire full,
    output wire empty,
    output wire [6:0] count
);
    reg [15:0] mem [0:63];
    reg [5:0] wr_ptr, rd_ptr;
    reg [6:0] used;
    wire push = wr_en && !full;
    wire pop = rd_en && !empty;

    assign rd_data = mem[rd_ptr];
    assign full = (used == 64);
    assign empty = (used == 0);
    assign count = used;

    always @(posedge clk) begin
        if (rst || clear) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            used <= 0;
        end else begin
            if (push) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (pop) rd_ptr <= rd_ptr + 1'b1;
            case ({push, pop})
                2'b10: used <= used + 1'b1;
                2'b01: used <= used - 1'b1;
                default: used <= used;
            endcase
        end
    end
endmodule
