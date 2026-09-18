// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : eeprom_iic_master.v
// Module  : eeprom_iic_master
// Created : 2026-06-16
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// Single-byte 24C64 transactions at 100 kHz. Transaction ordering follows
// the course Part 2 net11 IIC master; this subset adds open-drain lines,
// explicit ACK error/done signals, and one-byte read/write commands.
module eeprom_iic_master #(
    parameter integer HALF_TICKS = 250 // 50 MHz / (2 * 100 kHz)
) (
    input wire clk,
    input wire rst,
    input wire start,
    input wire read_not_write,
    input wire [15:0] word_addr,
    input wire [7:0] write_data,
    inout wire scl,
    inout wire sda,
    output wire busy,
    output reg done,
    output reg ack_error,
    output reg [7:0] read_data
);
    localparam [3:0] IDLE=0, START_HIGH=1, START_LOW=2,
        BIT_LOW=3, BIT_HIGH=4, ACK_LOW=5, ACK_HIGH=6,
        RESTART_LOW=7, RESTART_HIGH=8, RESTART_START=9,
        READ_LOW=10, READ_HIGH=11, NACK_LOW=12, NACK_HIGH=13,
        STOP_LOW=14, STOP_HIGH=15;
    // STOP release uses a separate flag while in STOP_HIGH, so the bus has
    // a full high half-period with SDA low before the rising STOP edge.
    reg [3:0] state;
    reg [15:0] div_count;
    reg [2:0] bit_index;
    reg [2:0] stage;
    reg [7:0] tx_byte;
    reg [15:0] address_latched;
    reg [7:0] data_latched;
    reg do_read;
    reg scl_low, sda_low;
    reg stop_release;
    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;
    assign busy = state != IDLE;

    always @* begin
        scl_low = 0;
        sda_low = 0;
        case (state)
            START_LOW, RESTART_START: sda_low = 1;
            BIT_LOW: begin scl_low = 1; sda_low = !tx_byte[bit_index]; end
            BIT_HIGH: sda_low = !tx_byte[bit_index];
            ACK_LOW, RESTART_LOW, READ_LOW, NACK_LOW: scl_low = 1;
            STOP_LOW: begin scl_low = 1; sda_low = 1; end
            STOP_HIGH: sda_low = !stop_release;
            default: begin end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            div_count <= 0;
            bit_index <= 7;
            stage <= 0;
            tx_byte <= 0;
            address_latched <= 0;
            data_latched <= 0;
            do_read <= 0;
            done <= 0;
            ack_error <= 0;
            read_data <= 0;
            stop_release <= 0;
        end else begin
            done <= 0;
            if (state == IDLE) begin
                div_count <= 0;
                if (start) begin
                    address_latched <= word_addr;
                    data_latched <= write_data;
                    do_read <= read_not_write;
                    stage <= 0;
                    tx_byte <= 8'hA0; // 7-bit address 0x50 + write
                    bit_index <= 7;
                    ack_error <= 0;
                    read_data <= 0;
                    stop_release <= 0;
                    state <= START_HIGH;
                end
            end else if (div_count == HALF_TICKS-1) begin
                div_count <= 0;
                case (state)
                    START_HIGH: state <= START_LOW;
                    START_LOW: state <= BIT_LOW;
                    BIT_LOW: state <= BIT_HIGH;
                    BIT_HIGH: begin
                        if (bit_index == 0) state <= ACK_LOW;
                        else begin bit_index <= bit_index-1'b1; state <= BIT_LOW; end
                    end
                    ACK_LOW: state <= ACK_HIGH;
                    ACK_HIGH: if (sda !== 1'b0) begin
                        ack_error <= 1;
                        state <= STOP_LOW;
                    end else case (stage)
                        0: begin stage <= 1; tx_byte <= address_latched[15:8];
                                 bit_index <= 7; state <= BIT_LOW; end
                        1: begin stage <= 2; tx_byte <= address_latched[7:0];
                                 bit_index <= 7; state <= BIT_LOW; end
                        2: if (do_read) state <= RESTART_LOW;
                           else begin stage <= 3; tx_byte <= data_latched;
                                      bit_index <= 7; state <= BIT_LOW; end
                        3: state <= STOP_LOW;
                        4: begin bit_index <= 7; state <= READ_LOW; end
                        default: state <= STOP_LOW;
                    endcase
                    RESTART_LOW: state <= RESTART_HIGH;
                    RESTART_HIGH: state <= RESTART_START;
                    RESTART_START: begin stage <= 4; tx_byte <= 8'hA1;
                                         bit_index <= 7; state <= BIT_LOW; end
                    READ_LOW: state <= READ_HIGH;
                    READ_HIGH: begin
                        read_data[bit_index] <= sda;
                        if (bit_index == 0) state <= NACK_LOW;
                        else begin bit_index <= bit_index-1'b1; state <= READ_LOW; end
                    end
                    NACK_LOW: state <= NACK_HIGH;
                    NACK_HIGH: state <= STOP_LOW;
                    STOP_LOW: state <= STOP_HIGH;
                    STOP_HIGH: if (!stop_release) stop_release <= 1;
                               else begin state <= IDLE; done <= 1; end
                    default: state <= IDLE;
                endcase
            end else div_count <= div_count + 1'b1;
        end
    end
endmodule
