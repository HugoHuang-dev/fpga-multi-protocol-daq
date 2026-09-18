// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : top_crc16.v
// Module  : top_crc16
// Created : 2026-05-25
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// Project 1 protocol v2: A5 5A TYPE SEQ LEN PAYLOAD CRC16_LO CRC16_HI.
// CRC-16/MODBUS over TYPE..PAYLOAD, using course Part 2 net6 crc16_d8.v.
module top_crc16 (
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

    localparam [2:0] P_HEAD1 = 0, P_HEAD2 = 1, P_TYPE = 2,
                     P_SEQ = 3, P_LEN = 4, P_PAYLOAD = 5,
                     P_CRC_LO = 6, P_CRC_HI = 7;
    reg [2:0] parse_state;
    reg [7:0] cmd_type, cmd_seq, cmd_len, bytes_left, rx_crc_low;
    reg request_valid;
    reg [7:0] request_seq, request_type;
    wire [15:0] rx_crc16;
    wire rx_crc_reset = rx_valid && parse_state == P_HEAD2 && rx_data == 8'h5A;
    wire rx_crc_feed = rx_valid &&
        (parse_state == P_TYPE || parse_state == P_SEQ ||
         parse_state == P_LEN || parse_state == P_PAYLOAD);

    crc16_d8 rx_crc_inst (
        .clk(clkin_50m), .reset(rst), .crc_din_vld(rx_crc_feed),
        .crc_din(rx_data), .crc_dout_f(rx_crc16), .crc_done(rx_crc_reset)
    );

    always @(posedge clkin_50m) begin
        if (rst) begin
            parse_state <= P_HEAD1;
            cmd_type <= 0;
            cmd_seq <= 0;
            cmd_len <= 0;
            bytes_left <= 0;
            rx_crc_low <= 0;
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
                        parse_state <= P_TYPE;
                    end else if (rx_data != 8'hA5) parse_state <= P_HEAD1;
                    P_TYPE: begin
                        cmd_type <= rx_data;
                        parse_state <= P_SEQ;
                    end
                    P_SEQ: begin
                        cmd_seq <= rx_data;
                        parse_state <= P_LEN;
                    end
                    P_LEN: begin
                        cmd_len <= rx_data;
                        bytes_left <= rx_data;
                        parse_state <= (rx_data == 0) ? P_CRC_LO : P_PAYLOAD;
                    end
                    P_PAYLOAD: begin
                        bytes_left <= bytes_left - 1'b1;
                        if (bytes_left == 1) parse_state <= P_CRC_LO;
                    end
                    P_CRC_LO: begin
                        rx_crc_low <= rx_data;
                        parse_state <= P_CRC_HI;
                    end
                    P_CRC_HI: begin
                        if ({rx_data, rx_crc_low} == rx_crc16 && cmd_len == 0 &&
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

    // 81 = PING response (one version byte: 02).
    // 82 = XADC response (two bytes, big endian 12-bit raw code).
    // E0 = XADC not ready (one error-code byte).
    reg [7:0] response_seq;
    reg [7:0] response_type, response_len, response_data0, response_data1;
    reg [3:0] send_index;
    reg send_state;
    localparam S_IDLE = 1'b0, S_ENQUEUE = 1'b1;
    wire [15:0] tx_crc16;
    wire tx_crc_reset = request_valid && send_state == S_IDLE;
    wire tx_crc_feed = fifo_wr_en && send_index >= 2 &&
        send_index <= (response_len == 2 ? 6 : 5);

    crc16_d8 tx_crc_inst (
        .clk(clkin_50m), .reset(rst), .crc_din_vld(tx_crc_feed),
        .crc_din(fifo_wr_data), .crc_dout_f(tx_crc16),
        .crc_done(tx_crc_reset)
    );

    assign fifo_wr_en = (send_state == S_ENQUEUE) && fifo_wr_ready;

    always @* begin
        case (send_index)
            0: fifo_wr_data = 8'hA5;
            1: fifo_wr_data = 8'h5A;
            2: fifo_wr_data = response_type;
            3: fifo_wr_data = response_seq;
            4: fifo_wr_data = response_len;
            5: fifo_wr_data = response_data0;
            6: fifo_wr_data = response_len == 2 ? response_data1 : tx_crc16[7:0];
            7: fifo_wr_data = response_len == 2 ? tx_crc16[7:0] : tx_crc16[15:8];
            8: fifo_wr_data = tx_crc16[15:8];
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
                        response_data0 <= 2;
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
                    if (send_index == (response_len == 2 ? 8 : 7))
                        send_state <= S_IDLE;
                    else send_index <= send_index + 1'b1;
                end
                default: send_state <= S_IDLE;
            endcase
        end
    end
endmodule
