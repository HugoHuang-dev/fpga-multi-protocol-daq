// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : pcf8563_iic_master.v
// Module  : pcf8563_iic_master
// Created : 2026-07-05
// Revised : 2026-09-18
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// PCF8563 register 02h..08h in one I2C access, as required for a coherent
// calendar snapshot. Open-drain outputs share the board bus with the 24C64.
module pcf8563_iic_master #(
    parameter integer HALF_TICKS = 250
) (
    input wire clk, rst, start, write_not_read,
    input wire [55:0] write_data, // seconds, minutes, hours, day, weekday, month, year
    inout wire scl, sda,
    output wire busy,
    output reg done, ack_error,
    output reg [55:0] read_data
);
    localparam [3:0] IDLE=0, START_HIGH=1, START_LOW=2,
        SEND_LOW=3, SEND_HIGH=4, ACK_LOW=5, ACK_HIGH=6,
        RESTART_LOW=7, RESTART_HIGH=8, RESTART_START=9,
        READ_LOW=10, READ_HIGH=11, READ_ACK_LOW=12,
        READ_ACK_HIGH=13, STOP_LOW=14, STOP_HIGH=15;
    reg [3:0] state;
    reg [15:0] div_count;
    reg [2:0] bit_index, byte_index;
    reg [2:0] phase; // 0 addr W, 1 pointer, 2 addr R, 3 write data, 4 read data
    reg [7:0] tx_byte;
    reg [55:0] data_latched;
    reg do_write, stop_release;
    reg scl_low, sda_low;
    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;
    assign busy = state != IDLE;

    always @* begin
        scl_low = 0;
        sda_low = 0;
        case (state)
            START_LOW, RESTART_START: sda_low = 1;
            SEND_LOW: begin scl_low = 1; sda_low = !tx_byte[bit_index]; end
            SEND_HIGH: sda_low = !tx_byte[bit_index];
            ACK_LOW, RESTART_LOW, READ_LOW: scl_low = 1;
            READ_ACK_LOW: begin scl_low = 1; sda_low = byte_index != 6; end
            READ_ACK_HIGH: sda_low = byte_index != 6;
            STOP_LOW: begin scl_low = 1; sda_low = 1; end
            STOP_HIGH: sda_low = !stop_release;
            default: begin end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; div_count <= 0; bit_index <= 7;
            byte_index <= 0; phase <= 0; tx_byte <= 0;
            data_latched <= 0; do_write <= 0;
            read_data <= 0; ack_error <= 0; done <= 0;
            stop_release <= 0;
        end else begin
            done <= 0;
            if (state == IDLE) begin
                div_count <= 0;
                if (start) begin
                    do_write <= write_not_read;
                    data_latched <= write_data;
                    read_data <= 0;
                    ack_error <= 0;
                    phase <= 0; byte_index <= 0; bit_index <= 7;
                    tx_byte <= 8'hA2; // 7-bit address 0x51, write
                    stop_release <= 0;
                    state <= START_HIGH;
                end
            end else if (div_count == HALF_TICKS-1) begin
                div_count <= 0;
                case (state)
                    START_HIGH: state <= START_LOW;
                    START_LOW: state <= SEND_LOW;
                    SEND_LOW: state <= SEND_HIGH;
                    SEND_HIGH: if (bit_index == 0) state <= ACK_LOW;
                               else begin bit_index <= bit_index-1'b1; state <= SEND_LOW; end
                    ACK_LOW: state <= ACK_HIGH;
                    ACK_HIGH: if (sda !== 1'b0) begin
                        ack_error <= 1; state <= STOP_LOW;
                    end else case (phase)
                        0: begin phase <= 1; tx_byte <= 8'h02;
                                 bit_index <= 7; state <= SEND_LOW; end
                        1: if (do_write) begin
                               phase <= 3; byte_index <= 0;
                               tx_byte <= data_latched[55:48];
                               bit_index <= 7; state <= SEND_LOW;
                           end else state <= RESTART_LOW;
                        2: begin phase <= 4; byte_index <= 0;
                                 bit_index <= 7; state <= READ_LOW; end
                        3: if (byte_index == 6) state <= STOP_LOW;
                           else begin
                               byte_index <= byte_index+1'b1;
                               tx_byte <= data_latched[55-(byte_index+1'b1)*8 -: 8];
                               bit_index <= 7; state <= SEND_LOW;
                           end
                        default: state <= STOP_LOW;
                    endcase
                    RESTART_LOW: state <= RESTART_HIGH;
                    RESTART_HIGH: state <= RESTART_START;
                    RESTART_START: begin phase <= 2; tx_byte <= 8'hA3;
                                         bit_index <= 7; state <= SEND_LOW; end
                    READ_LOW: state <= READ_HIGH;
                    READ_HIGH: begin
                        read_data[48-byte_index*8+bit_index] <= sda;
                        if (bit_index == 0) state <= READ_ACK_LOW;
                        else begin bit_index <= bit_index-1'b1; state <= READ_LOW; end
                    end
                    READ_ACK_LOW: state <= READ_ACK_HIGH;
                    READ_ACK_HIGH: if (byte_index == 6) state <= STOP_LOW;
                                   else begin byte_index <= byte_index+1'b1;
                                              bit_index <= 7; state <= READ_LOW; end
                    STOP_LOW: state <= STOP_HIGH;
                    STOP_HIGH: if (!stop_release) stop_release <= 1;
                               else begin state <= IDLE; done <= 1; end
                    default: state <= IDLE;
                endcase
            end else div_count <= div_count + 1'b1;
        end
    end
endmodule
