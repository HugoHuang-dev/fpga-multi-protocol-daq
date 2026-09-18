// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : uart_rx.v
// Module  : uart_rx
// Created : 2026-05-07
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// 8N1 receiver. rx_valid is a one-clock pulse after a valid stop bit.
module uart_rx #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD = 115200
) (
    input wire clk,
    input wire rst,
    input wire rx_pin,
    output reg [7:0] rx_data,
    output reg rx_valid
);
    localparam integer BIT_TICKS = (CLK_HZ + BAUD / 2) / BAUD;
    localparam integer HALF_TICKS = BIT_TICKS / 2;
    localparam [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg rx_meta, rx_sync;
    reg [1:0] state;
    reg [15:0] ticks;
    reg [2:0] bit_index;
    reg [7:0] shift;

    always @(posedge clk) begin
        rx_meta <= rx_pin;
        rx_sync <= rx_meta;
        if (rst) begin
            state <= IDLE;
            ticks <= 0;
            bit_index <= 0;
            shift <= 0;
            rx_data <= 0;
            rx_valid <= 0;
        end else begin
            rx_valid <= 0;
            case (state)
                IDLE: if (!rx_sync) begin
                    ticks <= HALF_TICKS - 1;
                    state <= START;
                end
                START: if (ticks == 0) begin
                    if (!rx_sync) begin
                        ticks <= BIT_TICKS - 1;
                        bit_index <= 0;
                        state <= DATA;
                    end else state <= IDLE;
                end else ticks <= ticks - 1'b1;
                DATA: if (ticks == 0) begin
                    shift[bit_index] <= rx_sync;
                    ticks <= BIT_TICKS - 1;
                    if (bit_index == 7) state <= STOP;
                    else bit_index <= bit_index + 1'b1;
                end else ticks <= ticks - 1'b1;
                STOP: if (ticks == 0) begin
                    if (rx_sync) begin
                        rx_data <= shift;
                        rx_valid <= 1;
                    end
                    state <= IDLE;
                end else ticks <= ticks - 1'b1;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
