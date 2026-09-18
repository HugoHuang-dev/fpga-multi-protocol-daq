// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : uart_tx.v
// Module  : uart_tx
// Created : 2026-05-07
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// Accepts tx_start only while tx_ready is high; sends 8N1, LSB first.
module uart_tx #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD = 115200
) (
    input wire clk,
    input wire rst,
    input wire [7:0] tx_data,
    input wire tx_start,
    output wire tx_ready,
    output reg tx_pin
);
    localparam integer BIT_TICKS = (CLK_HZ + BAUD / 2) / BAUD;
    localparam [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;
    reg [1:0] state;
    reg [15:0] ticks;
    reg [2:0] bit_index;
    reg [7:0] shift;

    assign tx_ready = (state == IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            ticks <= 0;
            bit_index <= 0;
            shift <= 0;
            tx_pin <= 1;
        end else begin
            case (state)
                IDLE: if (tx_start) begin
                    shift <= tx_data;
                    tx_pin <= 0;
                    ticks <= BIT_TICKS - 1;
                    state <= START;
                end
                START: if (ticks == 0) begin
                    tx_pin <= shift[0];
                    ticks <= BIT_TICKS - 1;
                    bit_index <= 0;
                    state <= DATA;
                end else ticks <= ticks - 1'b1;
                DATA: if (ticks == 0) begin
                    shift <= {1'b0, shift[7:1]};
                    ticks <= BIT_TICKS - 1;
                    if (bit_index == 7) begin
                        tx_pin <= 1;
                        state <= STOP;
                    end else begin
                        tx_pin <= shift[1];
                        bit_index <= bit_index + 1'b1;
                    end
                end else ticks <= ticks - 1'b1;
                STOP: if (ticks == 0) state <= IDLE;
                      else ticks <= ticks - 1'b1;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
