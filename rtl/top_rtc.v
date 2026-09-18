// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : top_rtc.v
// Module  : top_rtc
// Created : 2026-07-05
// Revised : 2026-09-18
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// Project 1 v8: four XADC channels, EEPROM, and board PCF8563 RTC.
module top_rtc #(
    parameter integer RTC_POLL_CYCLES = 50000000
) (
    input wire clkin_50m,
    input wire rst_n,
    input wire uart_rxd,
    output wire uart_txd,
    inout wire iic_scl,
    inout wire iic_sda,
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

    wire [11:0] temperature_raw, vccint_raw, vccaux_raw, vccbram_raw;
    wire [3:0] xadc_valid;
    wire temperature_valid = xadc_valid[0];
    xadc_multichannel xadc_inst (.clk(clkin_50m), .rst(rst),
        .temperature(temperature_raw), .vccint(vccint_raw),
        .vccaux(vccaux_raw), .vccbram(vccbram_raw),
        .valid_mask(xadc_valid));

    localparam [2:0] P_HEAD1=0, P_HEAD2=1, P_TYPE=2, P_SEQ=3,
                     P_LEN=4, P_PAYLOAD=5, P_CRC_LO=6, P_CRC_HI=7;
    reg [2:0] parse_state;
    reg [7:0] cmd_type, cmd_seq, cmd_len, bytes_left, rx_crc_low;
    reg [7:0] cmd_payload0, cmd_payload1, cmd_payload2;
    reg [7:0] cmd_payload3, cmd_payload4, cmd_payload5, cmd_payload6;
    reg request_valid;
    reg [7:0] request_type, request_seq;
    reg [15:0] request_addr;
    reg [7:0] request_data;
    reg [55:0] request_rtc_data;
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
            cmd_payload0 <= 0; cmd_payload1 <= 0; cmd_payload2 <= 0;
            cmd_payload3 <= 0; cmd_payload4 <= 0;
            cmd_payload5 <= 0; cmd_payload6 <= 0;
            bytes_left <= 0; rx_crc_low <= 0;
            request_valid <= 0; request_type <= 0; request_seq <= 0;
            request_addr <= 0; request_data <= 0;
            request_rtc_data <= 0;
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
                        if (bytes_left == cmd_len) cmd_payload0 <= rx_data;
                        else if (bytes_left == cmd_len-1'b1) cmd_payload1 <= rx_data;
                        else if (bytes_left == cmd_len-2'd2) cmd_payload2 <= rx_data;
                        else if (bytes_left == cmd_len-3'd3) cmd_payload3 <= rx_data;
                        else if (bytes_left == cmd_len-3'd4) cmd_payload4 <= rx_data;
                        else if (bytes_left == cmd_len-3'd5) cmd_payload5 <= rx_data;
                        else if (bytes_left == cmd_len-3'd6) cmd_payload6 <= rx_data;
                        bytes_left <= bytes_left - 1'b1;
                        if (bytes_left == 1) parse_state <= P_CRC_LO;
                    end
                    P_CRC_LO: begin rx_crc_low <= rx_data; parse_state <= P_CRC_HI; end
                    P_CRC_HI: begin
                        if ({rx_data, rx_crc_low} == rx_crc &&
                            ((cmd_len == 0 && (cmd_type == 8'h01 ||
                              cmd_type == 8'h02 || cmd_type == 8'h03 ||
                              cmd_type == 8'h04 || cmd_type == 8'h07)) ||
                             (cmd_type == 8'h05 && cmd_len == 2 &&
                              cmd_payload0[7:5] == 0) ||
                             (cmd_type == 8'h06 && cmd_len == 3 &&
                              cmd_payload0[7:5] == 0) ||
                             (cmd_type == 8'h08 && cmd_len == 7))) begin
                            request_valid <= 1;
                            request_type <= cmd_type;
                            request_seq <= cmd_seq;
                            request_addr <= {cmd_payload0,cmd_payload1};
                            request_data <= cmd_payload2;
                            request_rtc_data <= {cmd_payload0,cmd_payload1,
                                cmd_payload2,cmd_payload3,cmd_payload4,
                                cmd_payload5,cmd_payload6};
                            led0 <= ~led0;
                        end
                        parse_state <= P_HEAD1;
                    end
                    default: parse_state <= P_HEAD1;
                endcase
            end
        end
    end

    // Declare cross-block signals before their first use for ModelSim.
    wire rtc_busy;
    reg streaming;
    reg [7:0] next_batch_seq;
    wire iic_busy, iic_done, iic_ack_error;
    wire [7:0] iic_read_data;
    reg eeprom_inflight, eeprom_write_wait;
    reg [18:0] eeprom_wait_count;
    reg [7:0] eeprom_request_seq;
    reg eeprom_was_read;
    reg iic_reply_valid;
    reg [7:0] iic_reply_type, iic_reply_seq, iic_reply_data;
    wire take_iic_reply;
    wire iic_request = request_valid &&
        (request_type == 8'h05 || request_type == 8'h06);
    wire iic_start = iic_request && !iic_busy && !eeprom_inflight && !rtc_busy;
    eeprom_iic_master eeprom_bus (
        .clk(clkin_50m), .rst(rst), .start(iic_start),
        .read_not_write(request_type == 8'h05),
        .word_addr(request_addr), .write_data(request_data),
        .scl(iic_scl), .sda(iic_sda), .busy(iic_busy),
        .done(iic_done), .ack_error(iic_ack_error),
        .read_data(iic_read_data)
    );
    wire rtc_done, rtc_ack_error;
    wire [55:0] rtc_read_data;
    reg rtc_inflight, rtc_was_command, rtc_was_write;
    reg [7:0] rtc_command_seq;
    reg rtc_reply_valid;
    reg [7:0] rtc_reply_type, rtc_reply_seq, rtc_reply_len;
    reg [63:0] rtc_reply_data;
    wire take_rtc_reply;
    reg [25:0] rtc_poll_count;
    reg rtc_due;
    wire rtc_request = request_valid &&
        (request_type == 8'h07 || request_type == 8'h08);
    wire rtc_cmd_start = rtc_request && !rtc_busy && !rtc_inflight &&
        !rtc_reply_valid &&
        !iic_busy && !eeprom_inflight && !iic_request;
    wire rtc_auto_start = rtc_due && streaming && !rtc_request &&
        !iic_request && !rtc_busy && !rtc_inflight && !iic_busy &&
        !eeprom_inflight && !rtc_reply_valid;
    wire rtc_start = rtc_cmd_start || rtc_auto_start;
    pcf8563_iic_master rtc_bus (
        .clk(clkin_50m), .rst(rst), .start(rtc_start),
        .write_not_read(rtc_cmd_start && request_type == 8'h08),
        .write_data(request_rtc_data),
        .scl(iic_scl), .sda(iic_sda),
        .busy(rtc_busy), .done(rtc_done), .ack_error(rtc_ack_error),
        .read_data(rtc_read_data)
    );
    // A separate command or periodic read uses the same open-drain bus.
    // Never start either master while the other has an active transaction.
    always @(posedge clkin_50m) begin
        if (rst) begin
            rtc_inflight <= 0; rtc_was_command <= 0;
            rtc_was_write <= 0; rtc_command_seq <= 0;
            rtc_reply_valid <= 0; rtc_reply_type <= 0;
            rtc_reply_seq <= 0; rtc_reply_len <= 0;
            rtc_reply_data <= 0; rtc_poll_count <= 0; rtc_due <= 0;
        end else begin
            if (take_rtc_reply) rtc_reply_valid <= 0;
            if (!streaming) begin rtc_poll_count <= 0; rtc_due <= 0; end
            else if (rtc_poll_count == RTC_POLL_CYCLES-1) begin
                rtc_poll_count <= 0; rtc_due <= 1;
            end else rtc_poll_count <= rtc_poll_count + 1'b1;
            if (rtc_start) begin
                rtc_inflight <= 1;
                rtc_was_command <= rtc_cmd_start;
                rtc_was_write <= rtc_cmd_start && request_type == 8'h08;
                rtc_command_seq <= rtc_cmd_start ? request_seq : next_batch_seq;
                rtc_due <= 0;
            end
            if (rtc_done && rtc_inflight) begin
                rtc_inflight <= 0;
                rtc_reply_valid <= 1;
                rtc_reply_seq <= rtc_was_command ? rtc_command_seq : next_batch_seq;
                if (rtc_ack_error) begin
                    rtc_reply_type <= 8'hE3;
                    rtc_reply_len <= 1;
                    rtc_reply_data <= {8'h01,56'b0};
                end else if (rtc_was_write) begin
                    rtc_reply_type <= 8'h88;
                    rtc_reply_len <= 1;
                    rtc_reply_data <= 0;
                end else begin
                    rtc_reply_type <= rtc_was_command ? 8'h87 : 8'h92;
                    rtc_reply_len <= 8;
                    rtc_reply_data <= {next_batch_seq,rtc_read_data};
                end
            end
        end
    end
    // The course EEPROM controller uses a 10 ms post-write wait. Keep that
    // conservative guard for the board's unspecified 24C64 manufacturer.
    always @(posedge clkin_50m) begin
        if (rst) begin
            eeprom_inflight <= 0;
            eeprom_write_wait <= 0;
            eeprom_wait_count <= 0;
            eeprom_request_seq <= 0;
            eeprom_was_read <= 0;
            iic_reply_valid <= 0;
            iic_reply_type <= 0;
            iic_reply_seq <= 0;
            iic_reply_data <= 0;
        end else begin
            if (take_iic_reply) iic_reply_valid <= 0;
            if (iic_start) begin
                eeprom_inflight <= 1;
                eeprom_request_seq <= request_seq;
                eeprom_was_read <= request_type == 8'h05;
            end
            if (iic_done && eeprom_inflight) begin
                if (!eeprom_was_read && !iic_ack_error) begin
                    eeprom_write_wait <= 1;
                    eeprom_wait_count <= 0;
                end else begin
                    eeprom_inflight <= 0;
                    iic_reply_valid <= 1;
                    iic_reply_seq <= eeprom_request_seq;
                    iic_reply_type <= iic_ack_error ? 8'hE1 : 8'h85;
                    iic_reply_data <= iic_ack_error ? 8'h01 : iic_read_data;
                end
            end else if (eeprom_write_wait) begin
                if (eeprom_wait_count == 19'd499999) begin
                    eeprom_write_wait <= 0;
                    eeprom_inflight <= 0;
                    iic_reply_valid <= 1;
                    iic_reply_seq <= eeprom_request_seq;
                    iic_reply_type <= 8'h86;
                    iic_reply_data <= 8'h00;
                end else eeprom_wait_count <= eeprom_wait_count + 1'b1;
            end
        end
    end

    reg [15:0] drop_count;
    reg [15:0] sample_timer;
    reg [1:0] sample_channel;
    reg [11:0] selected_raw;
    wire [15:0] sample_data;
    wire [6:0] sample_count;
    wire sample_full, sample_empty;
    wire start_stream = request_valid && request_type == 8'h03;
    wire stop_stream = request_valid && request_type == 8'h04;
    wire sample_clear = start_stream && !streaming;
    wire sample_tick = streaming && sample_timer == 16'd49999;
    wire sample_enabled = &xadc_valid;
    wire sample_push = sample_tick && sample_enabled && !sample_full;
    wire sample_pop;
    always @* begin
        case (sample_channel)
            2'd0: selected_raw = temperature_raw;
            2'd1: selected_raw = vccint_raw;
            2'd2: selected_raw = vccaux_raw;
            2'd3: selected_raw = vccbram_raw;
        endcase
    end
    sample_fifo acquisition_fifo (.clk(clkin_50m), .rst(rst),
        .clear(sample_clear), .wr_en(sample_push),
        .wr_data({sample_channel, 2'b00, selected_raw}), .rd_en(sample_pop),
        .rd_data(sample_data), .full(sample_full), .empty(sample_empty),
        .count(sample_count));
    always @(posedge clkin_50m) begin
        if (rst) begin
            streaming <= 0;
            sample_timer <= 0;
            drop_count <= 0;
            sample_channel <= 0;
        end else begin
            if (start_stream) streaming <= 1;
            if (stop_stream) streaming <= 0;
            if (sample_clear) begin
                sample_timer <= 0;
                drop_count <= 0;
                sample_channel <= 0;
            end else if (sample_tick) sample_timer <= 0;
            else if (streaming) sample_timer <= sample_timer + 1'b1;
            if (sample_tick && sample_enabled)
                sample_channel <= sample_channel + 1'b1;
            if (sample_tick && sample_enabled && sample_full)
                drop_count <= drop_count + 1'b1;
        end
    end

    // A complete response or sample batch is placed into the UART byte FIFO
    // before selecting another frame, so command and stream bytes cannot mix.
    localparam [1:0] S_IDLE=0, S_REPLY=1, S_BATCH=2, S_RTC=3;
    reg [1:0] send_state;
    reg [5:0] send_index;
    reg [7:0] response_type, response_seq, response_len;
    reg [7:0] response_data0, response_data1;
    reg [63:0] response_rtc_data;
    reg pending;
    reg [7:0] pending_type, pending_seq, pending_len;
    reg [7:0] pending_data0, pending_data1;
    reg [7:0] batch_seq;
    reg [15:0] batch_drops;
    wire [15:0] tx_crc;
    assign take_iic_reply = send_state == S_IDLE && iic_reply_valid;
    assign take_rtc_reply = send_state == S_IDLE && rtc_reply_valid;
    wire frame_start = send_state == S_IDLE &&
        (rtc_reply_valid || iic_reply_valid || pending ||
         (streaming && sample_count >= 16));
    wire tx_crc_feed = tx_write && send_index >= 2 &&
        ((send_state == S_REPLY && send_index <= (response_len == 2 ? 6 : 5)) ||
         (send_state == S_BATCH && send_index <= 38) ||
         (send_state == S_RTC && send_index <= 12));
    crc16_d8 tx_crc_inst (.clk(clkin_50m), .reset(rst),
        .crc_din_vld(tx_crc_feed), .crc_din(tx_byte),
        .crc_dout_f(tx_crc), .crc_done(frame_start));
    assign tx_write = (send_state == S_REPLY || send_state == S_BATCH ||
                       send_state == S_RTC) && tx_ready;
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
                2: tx_byte = 8'h91;
                3: tx_byte = batch_seq;
                4: tx_byte = 8'd34;
                5: tx_byte = batch_drops[15:8];
                6: tx_byte = batch_drops[7:0];
                39: tx_byte = tx_crc[7:0];
                40: tx_byte = tx_crc[15:8];
                default: if (send_index >= 7 && send_index <= 38)
                    tx_byte = send_index[0] ? sample_data[15:8] : sample_data[7:0];
            endcase
        end else if (send_state == S_RTC) begin
            case (send_index)
                0: tx_byte = 8'hA5;
                1: tx_byte = 8'h5A;
                2: tx_byte = response_type;
                3: tx_byte = response_seq;
                4: tx_byte = 8'd8;
                13: tx_byte = tx_crc[7:0];
                14: tx_byte = tx_crc[15:8];
                default: if (send_index >= 5 && send_index <= 12)
                    tx_byte = response_rtc_data[63-(send_index-5)*8 -: 8];
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
            response_rtc_data <= 0;
            batch_seq <= 0; next_batch_seq <= 0; batch_drops <= 0;
        end else begin
            if (request_valid && !iic_start && !rtc_cmd_start) begin
                pending <= 1;
                pending_seq <= request_seq;
                case (request_type)
                    8'h01: begin
                        pending_type <= 8'h81; pending_len <= 1;
                        pending_data0 <= 3; pending_data1 <= 0;
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
                    8'h04: begin
                        pending_type <= 8'h84; pending_len <= 1;
                        pending_data0 <= 0; pending_data1 <= 0;
                    end
                    8'h07, 8'h08: begin
                        pending_type <= 8'hE4; pending_len <= 1;
                        pending_data0 <= 1; pending_data1 <= 0;
                    end
                    default: begin // EEPROM request while previous one is active
                        pending_type <= 8'hE2; pending_len <= 1;
                        pending_data0 <= 1; pending_data1 <= 0;
                    end
                endcase
            end
            case (send_state)
                S_IDLE: if (rtc_reply_valid) begin
                    response_type <= rtc_reply_type;
                    response_seq <= rtc_reply_seq;
                    response_len <= rtc_reply_len;
                    response_rtc_data <= rtc_reply_data;
                    response_data0 <= rtc_reply_data[63:56];
                    response_data1 <= 0;
                    send_index <= 0;
                    send_state <= rtc_reply_len == 8 ? S_RTC : S_REPLY;
                end else if (iic_reply_valid) begin
                    response_type <= iic_reply_type;
                    response_seq <= iic_reply_seq;
                    response_len <= 1;
                    response_data0 <= iic_reply_data;
                    response_data1 <= 0;
                    send_index <= 0;
                    send_state <= S_REPLY;
                end else if (pending) begin
                    response_type <= pending_type;
                    response_seq <= pending_seq;
                    response_len <= pending_len;
                    response_data0 <= pending_data0;
                    response_data1 <= pending_data1;
                    if (!request_valid || iic_start) pending <= 0;
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
                S_RTC: if (tx_write) begin
                    if (send_index == 14) send_state <= S_IDLE;
                    else send_index <= send_index + 1'b1;
                end
                default: send_state <= S_IDLE;
            endcase
        end
    end
endmodule
