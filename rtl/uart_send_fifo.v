// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : uart_send_fifo.v
// Module  : uart_send_fifo
// Created : 2026-05-18
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// UART transmitter with a first-word-fall-through 128-byte FIFO.
// Adaptation: the FIFO's first-word-fall-through output feeds our UART TX
// directly whenever the transmitter is ready. This avoids timing a separate
// read pulse around the transmitter busy signal.
module uart_send_fifo (
    input wire clk,
    input wire rst,
    input wire wr_en,
    input wire [7:0] wr_data,
    output wire wr_ready,
    output wire uart_txd
);
    wire [7:0] fifo_dout;
    wire fifo_full, fifo_empty;
    wire [7:0] data_count;
    wire tx_ready;
    wire fifo_rd_en = !fifo_empty && tx_ready;

    assign wr_ready = !fifo_full;

    fifo_w8xd128 fifo_inst (
        .clk(clk), .srst(rst),
        .din(wr_data), .wr_en(wr_en && wr_ready),
        .rd_en(fifo_rd_en), .dout(fifo_dout),
        .full(fifo_full), .empty(fifo_empty),
        .data_count(data_count)
    );

    uart_tx tx_inst (
        .clk(clk), .rst(rst), .tx_data(fifo_dout),
        .tx_start(fifo_rd_en), .tx_ready(tx_ready),
        .tx_pin(uart_txd)
    );
endmodule
