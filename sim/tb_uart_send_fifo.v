// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : tb_uart_send_fifo.v
// Module  : tb_uart_send_fifo
// Created : 2026-05-18
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_uart_send_fifo;
    localparam integer BIT_NS = 8680;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst = 1;
    reg wr_en = 0;
    reg [7:0] wr_data = 0;
    wire wr_ready, uart_txd;
    reg [7:0] received [0:129];
    reg [7:0] observed;
    integer received_count = 0;
    integer accepted = 0;
    integer i, bit_no;

    uart_send_fifo dut (
        .clk(clk), .rst(rst), .wr_en(wr_en), .wr_data(wr_data),
        .wr_ready(wr_ready), .uart_txd(uart_txd)
    );

    always begin
        @(negedge uart_txd);
        #(BIT_NS + BIT_NS / 2);
        observed = 0;
        for (bit_no = 0; bit_no < 8; bit_no = bit_no + 1) begin
            observed[bit_no] = uart_txd;
            #(BIT_NS);
        end
        if (uart_txd !== 1'b1) $fatal(1, "Missing stop bit");
        received[received_count] = observed;
        received_count = received_count + 1;
    end

    initial begin
        repeat (5) @(negedge clk);
        rst = 0;
        for (i = 0; i < 130; i = i + 1) begin
            @(negedge clk);
            wr_en = 1;
            wr_data = i[7:0];
            @(posedge clk);
            if (wr_ready) accepted = accepted + 1;
        end
        @(negedge clk);
        wr_en = 0;
        if (accepted != 129 || wr_ready !== 1'b0)
            $fatal(1, "FIFO full behavior mismatch: accepted=%0d", accepted);
        wait (received_count == accepted);
        for (i = 0; i < accepted; i = i + 1)
            if (received[i] !== i[7:0])
                $fatal(1, "FIFO order mismatch at byte %0d", i);
        if (wr_ready !== 1'b1) $fatal(1, "FIFO did not recover from full");
        $display("PASS: 129 accepted bytes, full backpressure, ordered UART drain");
        $finish;
    end

    initial begin
        #15000000;
        $fatal(1, "FIFO test timeout");
    end
endmodule
