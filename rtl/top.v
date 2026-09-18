// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : top.v
// Module  : top
// Created : 2026-05-12
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// Project 1 UART command link with PING and XADC temperature readout.
// Frame: A5 5A TYPE SEQ LEN PAYLOAD... CRC8
// CRC-8/ATM: polynomial 07, init 00, no reflection, no final xor.
module top (
    input wire clkin_50m,
    input wire rst_n,
    input wire uart_rxd,
    output wire uart_txd,
    output reg led0
);
    reg [15:0] startup = 16'd0;
    always @(posedge clkin_50m) begin
        if (!rst_n) startup <= 0;
        else if (!startup[15]) startup <= {startup[14:0], 1'b1};
    end
    wire rst = !rst_n || !startup[15];

    wire [7:0] rx_data;
    wire rx_valid;
    reg [7:0] fifo_wr_data;
    wire fifo_wr_ready;
    wire fifo_wr_en;

    uart_rx rx_inst (
        .clk(clkin_50m), .rst(rst), .rx_pin(uart_rxd),
        .rx_data(rx_data), .rx_valid(rx_valid)
    );
    uart_send_fifo send_fifo_inst (
        .clk(clkin_50m), .rst(rst),
        .wr_en(fifo_wr_en), .wr_data(fifo_wr_data),
        .wr_ready(fifo_wr_ready), .uart_txd(uart_txd)
    );

    wire [11:0] temperature_raw;
    wire temperature_valid;
    xadc_temp xadc_temp_inst (
        .clk(clkin_50m), .rst(rst),
        .sample(temperature_raw), .sample_valid(temperature_valid)
    );

    function [7:0] crc8_next;
        input [7:0] crc;
        input [7:0] data;
        reg [7:0] work;
        integer i;
        begin
            work = crc ^ data;
            for (i = 0; i < 8; i = i + 1)
                work = work[7] ? (work << 1) ^ 8'h07 : (work << 1);
            crc8_next = work;
        end
    endfunction

    localparam [2:0] P_HEAD1 = 0, P_HEAD2 = 1, P_TYPE = 2,
                     P_SEQ = 3, P_LEN = 4, P_PAYLOAD = 5, P_CRC = 6;
    reg [2:0] parse_state;
    reg [7:0] cmd_type, cmd_seq, cmd_len, bytes_left, crc;
    reg request_valid;
    reg [7:0] request_seq, request_type;

    always @(posedge clkin_50m) begin
        if (rst) begin
            parse_state <= P_HEAD1;
            cmd_type <= 0;
            cmd_seq <= 0;
            cmd_len <= 0;
            bytes_left <= 0;
            crc <= 0;
            request_valid <= 0;
            request_seq <= 0;
            request_type <= 0;
            led0 <= 0;
        end else begin
            request_valid <= 0;
            if (rx_valid) begin
                case (parse_state)
                    P_HEAD1: if (rx_data == 8'hA5) parse_state <= P_HEAD2;
                    P_HEAD2: if (rx_data == 8'h5A) begin
                        crc <= 0;
                        parse_state <= P_TYPE;
                    end else if (rx_data != 8'hA5) parse_state <= P_HEAD1;
                    P_TYPE: begin
                        cmd_type <= rx_data;
                        crc <= crc8_next(crc, rx_data);
                        parse_state <= P_SEQ;
                    end
                    P_SEQ: begin
                        cmd_seq <= rx_data;
                        crc <= crc8_next(crc, rx_data);
                        parse_state <= P_LEN;
                    end
                    P_LEN: begin
                        cmd_len <= rx_data;
                        bytes_left <= rx_data;
                        crc <= crc8_next(crc, rx_data);
                        parse_state <= (rx_data == 0) ? P_CRC : P_PAYLOAD;
                    end
                    P_PAYLOAD: begin
                        crc <= crc8_next(crc, rx_data);
                        bytes_left <= bytes_left - 1'b1;
                        if (bytes_left == 1) parse_state <= P_CRC;
                    end
                    P_CRC: begin
                        if (rx_data == crc && cmd_len == 0 &&
                            (cmd_type == 8'h01 || cmd_type == 8'h02)) begin
                            request_seq <= cmd_seq;
                            request_type <= cmd_type;
                            request_valid <= 1;
                            led0 <= ~led0;
                        end
                        parse_state <= P_HEAD1;
                    end
                    default: parse_state <= P_HEAD1;
                endcase
            end
        end
    end

    // 81 = PING response (one version byte).
    // 82 = XADC response (two bytes, big endian 12-bit raw code).
    // E0 = XADC not ready (one error-code byte).
    reg [7:0] response_seq;
    reg [7:0] response_type, response_len, response_data0, response_data1;
    reg [2:0] send_index;
    reg send_state;
    localparam S_IDLE = 1'b0, S_ENQUEUE = 1'b1;
    wire [7:0] response_crc_base = crc8_next(
        crc8_next(crc8_next(8'h00, response_type), response_seq),
        response_len);
    wire [7:0] response_crc = response_len == 2 ?
        crc8_next(crc8_next(response_crc_base, response_data0), response_data1) :
        crc8_next(response_crc_base, response_data0);

    assign fifo_wr_en = (send_state == S_ENQUEUE) && fifo_wr_ready;

    always @* begin
        case (send_index)
            0: fifo_wr_data = 8'hA5;
            1: fifo_wr_data = 8'h5A;
            2: fifo_wr_data = response_type;
            3: fifo_wr_data = response_seq;
            4: fifo_wr_data = response_len;
            5: fifo_wr_data = response_data0;
            6: fifo_wr_data = response_len == 2 ? response_data1 : response_crc;
            7: fifo_wr_data = response_crc;
            default: fifo_wr_data = 0;
        endcase
    end

    always @(posedge clkin_50m) begin
        if (rst) begin
            response_seq <= 0;
            response_type <= 0;
            response_len <= 0;
            response_data0 <= 0;
            response_data1 <= 0;
            send_index <= 0;
            send_state <= S_IDLE;
        end else begin
            case (send_state)
                S_IDLE: if (request_valid) begin
                    response_seq <= request_seq;
                    if (request_type == 8'h01) begin
                        response_type <= 8'h81;
                        response_len <= 1;
                        response_data0 <= 1;
                        response_data1 <= 0;
                    end else if (temperature_valid) begin
                        response_type <= 8'h82;
                        response_len <= 2;
                        response_data0 <= {4'h0, temperature_raw[11:8]};
                        response_data1 <= temperature_raw[7:0];
                    end else begin
                        response_type <= 8'hE0;
                        response_len <= 1;
                        response_data0 <= 1;
                        response_data1 <= 0;
                    end
                    send_index <= 0;
                    send_state <= S_ENQUEUE;
                end
                S_ENQUEUE: if (fifo_wr_en) begin
                    if (send_index == (response_len == 2 ? 7 : 6))
                        send_state <= S_IDLE;
                    else send_index <= send_index + 1'b1;
                end
                default: send_state <= S_IDLE;
            endcase
        end
    end
endmodule
