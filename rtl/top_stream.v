// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : top_stream.v
// Module  : top_stream
// Created : 2026-06-01
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// Project 1 v5: on-chip temperature -> acquisition FIFO -> batch CRC -> UART.
// Capture cadence is 1 kHz; this is NOT the XADC conversion rate.
module top_stream (
    input wire clkin_50m,
    input wire rst_n,
    input wire uart_rxd,
    output wire uart_txd,
    output reg led0
);
    reg [15:0] startup = 0;
    always @(posedge clkin_50m) begin
        if (!rst_n) startup <= 0;
        else if (!startup[15]) startup <= {startup[14:0], 1'b1};
    end
    wire rst = !rst_n || !startup[15];

    wire [7:0] rx_data;
    wire rx_valid;
    reg [7:0] tx_byte;
    wire tx_ready;
    wire tx_write;
    uart_rx rx_inst (.clk(clkin_50m), .rst(rst), .rx_pin(uart_rxd),
                     .rx_data(rx_data), .rx_valid(rx_valid));
    uart_send_fifo send_fifo_inst (.clk(clkin_50m), .rst(rst),
        .wr_en(tx_write), .wr_data(tx_byte), .wr_ready(tx_ready),
        .uart_txd(uart_txd));

    wire [11:0] temperature_raw;
    wire temperature_valid;
    xadc_temp xadc_temp_inst (.clk(clkin_50m), .rst(rst),
        .sample(temperature_raw), .sample_valid(temperature_valid));

    localparam [2:0] P_HEAD1=0, P_HEAD2=1, P_TYPE=2, P_SEQ=3,
                     P_LEN=4, P_PAYLOAD=5, P_CRC_LO=6, P_CRC_HI=7;
    reg [2:0] parse_state;
    reg [7:0] cmd_type, cmd_seq, cmd_len, bytes_left, rx_crc_low;
    reg request_valid;
    reg [7:0] request_type, request_seq;
    wire [15:0] rx_crc;
    wire rx_crc_reset = rx_valid && parse_state == P_HEAD2 && rx_data == 8'h5A;
    wire rx_crc_feed = rx_valid && (parse_state == P_TYPE ||
        parse_state == P_SEQ || parse_state == P_LEN || parse_state == P_PAYLOAD);
    crc16_d8 rx_crc_inst (.clk(clkin_50m), .reset(rst),
        .crc_din_vld(rx_crc_feed), .crc_din(rx_data),
        .crc_dout_f(rx_crc), .crc_done(rx_crc_reset));

    always @(posedge clkin_50m) begin
        if (rst) begin
            parse_state <= P_HEAD1;
            cmd_type <= 0; cmd_seq <= 0; cmd_len <= 0;
            bytes_left <= 0; rx_crc_low <= 0;
            request_valid <= 0; request_type <= 0; request_seq <= 0;
            led0 <= 0;
        end else begin
            request_valid <= 0;
            if (rx_valid) begin
                case (parse_state)
                    P_HEAD1: if (rx_data == 8'hA5) parse_state <= P_HEAD2;
                    P_HEAD2: if (rx_data == 8'h5A) parse_state <= P_TYPE;
                             else if (rx_data != 8'hA5) parse_state <= P_HEAD1;
                    P_TYPE: begin cmd_type <= rx_data; parse_state <= P_SEQ; end
                    P_SEQ: begin cmd_seq <= rx_data; parse_state <= P_LEN; end
                    P_LEN: begin
                        cmd_len <= rx_data;
                        bytes_left <= rx_data;
                        parse_state <= rx_data == 0 ? P_CRC_LO : P_PAYLOAD;
                    end
                    P_PAYLOAD: begin
                        bytes_left <= bytes_left - 1'b1;
                        if (bytes_left == 1) parse_state <= P_CRC_LO;
                    end
                    P_CRC_LO: begin rx_crc_low <= rx_data; parse_state <= P_CRC_HI; end
                    P_CRC_HI: begin
                        if ({rx_data, rx_crc_low} == rx_crc && cmd_len == 0 &&
                            (cmd_type == 8'h01 || cmd_type == 8'h02 ||
                             cmd_type == 8'h03 || cmd_type == 8'h04)) begin
                            request_valid <= 1;
                            request_type <= cmd_type;
                            request_seq <= cmd_seq;
                            led0 <= ~led0;
                        end
                        parse_state <= P_HEAD1;
                    end
                    default: parse_state <= P_HEAD1;
                endcase
            end
        end
    end

    reg streaming;
    reg [15:0] drop_count;
    reg [15:0] sample_timer;
    wire [15:0] sample_data;
    wire [6:0] sample_count;
    wire sample_full, sample_empty;
    wire start_stream = request_valid && request_type == 8'h03;
    wire stop_stream = request_valid && request_type == 8'h04;
    wire sample_clear = start_stream && !streaming;
    wire sample_tick = streaming && sample_timer == 16'd49999;
    wire sample_push = sample_tick && temperature_valid && !sample_full;
    wire sample_pop;
    sample_fifo acquisition_fifo (.clk(clkin_50m), .rst(rst),
        .clear(sample_clear), .wr_en(sample_push),
        .wr_data({4'b0, temperature_raw}), .rd_en(sample_pop),
        .rd_data(sample_data), .full(sample_full), .empty(sample_empty),
        .count(sample_count));
    always @(posedge clkin_50m) begin
        if (rst) begin
            streaming <= 0;
            sample_timer <= 0;
            drop_count <= 0;
        end else begin
            if (start_stream) streaming <= 1;
            if (stop_stream) streaming <= 0;
            if (sample_clear) begin
                sample_timer <= 0;
                drop_count <= 0;
            end else if (sample_tick) sample_timer <= 0;
            else if (streaming) sample_timer <= sample_timer + 1'b1;
            if (sample_tick && temperature_valid && sample_full)
                drop_count <= drop_count + 1'b1;
        end
    end

    // A complete response or sample batch is placed into the UART byte FIFO
    // before selecting another frame, so command and stream bytes cannot mix.
    localparam [1:0] S_IDLE=0, S_REPLY=1, S_BATCH=2;
    reg [1:0] send_state;
    reg [5:0] send_index;
    reg [7:0] response_type, response_seq, response_len;
    reg [7:0] response_data0, response_data1;
    reg pending;
    reg [7:0] pending_type, pending_seq, pending_len;
    reg [7:0] pending_data0, pending_data1;
    reg [7:0] batch_seq, next_batch_seq;
    reg [15:0] batch_drops;
    wire [15:0] tx_crc;
    wire frame_start = send_state == S_IDLE &&
        (pending || (streaming && sample_count >= 16));
    wire tx_crc_feed = tx_write && send_index >= 2 &&
        ((send_state == S_REPLY && send_index <= (response_len == 2 ? 6 : 5)) ||
         (send_state == S_BATCH && send_index <= 38));
    crc16_d8 tx_crc_inst (.clk(clkin_50m), .reset(rst),
        .crc_din_vld(tx_crc_feed), .crc_din(tx_byte),
        .crc_dout_f(tx_crc), .crc_done(frame_start));
    assign tx_write = (send_state == S_REPLY || send_state == S_BATCH) && tx_ready;
    assign sample_pop = send_state == S_BATCH && tx_write &&
        send_index >= 8 && send_index <= 38 && !send_index[0];

    always @* begin
        tx_byte = 0;
        if (send_state == S_REPLY) begin
            case (send_index)
                0: tx_byte = 8'hA5;
                1: tx_byte = 8'h5A;
                2: tx_byte = response_type;
                3: tx_byte = response_seq;
                4: tx_byte = response_len;
                5: tx_byte = response_data0;
                6: tx_byte = response_len == 2 ? response_data1 : tx_crc[7:0];
                7: tx_byte = response_len == 2 ? tx_crc[7:0] : tx_crc[15:8];
                8: tx_byte = tx_crc[15:8];
                default: tx_byte = 0;
            endcase
        end else if (send_state == S_BATCH) begin
            case (send_index)
                0: tx_byte = 8'hA5;
                1: tx_byte = 8'h5A;
                2: tx_byte = 8'h90;
                3: tx_byte = batch_seq;
                4: tx_byte = 8'd34;
                5: tx_byte = batch_drops[15:8];
                6: tx_byte = batch_drops[7:0];
                39: tx_byte = tx_crc[7:0];
                40: tx_byte = tx_crc[15:8];
                default: if (send_index >= 7 && send_index <= 38)
                    tx_byte = send_index[0] ? sample_data[15:8] : sample_data[7:0];
            endcase
        end
    end

    always @(posedge clkin_50m) begin
        if (rst) begin
            send_state <= S_IDLE; send_index <= 0;
            pending <= 0;
            pending_type <= 0; pending_seq <= 0; pending_len <= 0;
            pending_data0 <= 0; pending_data1 <= 0;
            response_type <= 0; response_seq <= 0; response_len <= 0;
            response_data0 <= 0; response_data1 <= 0;
            batch_seq <= 0; next_batch_seq <= 0; batch_drops <= 0;
        end else begin
            if (request_valid) begin
                pending <= 1;
                pending_seq <= request_seq;
                case (request_type)
                    8'h01: begin
                        pending_type <= 8'h81; pending_len <= 1;
                        pending_data0 <= 2; pending_data1 <= 0;
                    end
                    8'h02: if (temperature_valid) begin
                        pending_type <= 8'h82; pending_len <= 2;
                        pending_data0 <= {4'b0, temperature_raw[11:8]};
                        pending_data1 <= temperature_raw[7:0];
                    end else begin
                        pending_type <= 8'hE0; pending_len <= 1;
                        pending_data0 <= 1; pending_data1 <= 0;
                    end
                    8'h03: begin
                        pending_type <= 8'h83; pending_len <= 1;
                        pending_data0 <= 1; pending_data1 <= 0;
                    end
                    default: begin
                        pending_type <= 8'h84; pending_len <= 1;
                        pending_data0 <= 0; pending_data1 <= 0;
                    end
                endcase
            end
            case (send_state)
                S_IDLE: if (pending) begin
                    response_type <= pending_type;
                    response_seq <= pending_seq;
                    response_len <= pending_len;
                    response_data0 <= pending_data0;
                    response_data1 <= pending_data1;
                    if (!request_valid) pending <= 0;
                    send_index <= 0;
                    send_state <= S_REPLY;
                end else if (streaming && sample_count >= 16) begin
                    batch_seq <= next_batch_seq;
                    next_batch_seq <= next_batch_seq + 1'b1;
                    batch_drops <= drop_count;
                    send_index <= 0;
                    send_state <= S_BATCH;
                end
                S_REPLY: if (tx_write) begin
                    if (send_index == (response_len == 2 ? 8 : 7))
                        send_state <= S_IDLE;
                    else send_index <= send_index + 1'b1;
                end
                S_BATCH: if (tx_write) begin
                    if (send_index == 40) send_state <= S_IDLE;
                    else send_index <= send_index + 1'b1;
                end
                default: send_state <= S_IDLE;
            endcase
        end
    end
endmodule
