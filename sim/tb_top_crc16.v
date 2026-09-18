// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : tb_top_crc16.v
// Module  : tb_top_crc16
// Created : 2026-05-25
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_top_crc16;
    localparam integer BIT_NS = 8680;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst_n = 0;
    reg uart_rxd = 1;
    wire uart_txd, led0;
    reg [7:0] received [0:63];
    reg [7:0] observed;
    reg [7:0] expected_lo, expected_hi;
    integer received_count = 0;
    integer i, j;

    top_crc16 dut (
        .clkin_50m(clk), .rst_n(rst_n), .uart_rxd(uart_rxd),
        .uart_txd(uart_txd), .led0(led0)
    );

    task send_byte;
        input [7:0] value;
        integer bit_no;
        begin
            @(negedge clk);
            uart_rxd = 0;
            #(BIT_NS);
            for (bit_no = 0; bit_no < 8; bit_no = bit_no + 1) begin
                uart_rxd = value[bit_no];
                #(BIT_NS);
            end
            uart_rxd = 1;
            #(BIT_NS);
        end
    endtask

    task send_ping;
        input [7:0] seq, crc_lo, crc_hi;
        begin
            send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h01);
            send_byte(seq); send_byte(8'h00);
            send_byte(crc_lo); send_byte(crc_hi);
        end
    endtask

    always begin
        @(negedge uart_txd);
        #(BIT_NS + BIT_NS / 2);
        observed = 0;
        for (i = 0; i < 8; i = i + 1) begin
            observed[i] = uart_txd;
            #(BIT_NS);
        end
        if (uart_txd !== 1'b1) $fatal(1, "Missing stop bit");
        received[received_count] = observed;
        received_count = received_count + 1;
    end

    initial begin
        #200; rst_n = 1;
        #1000;
        send_ping(8'h00, 8'h20, 8'h00);
        wait (received_count == 8);
        if (received[0] !== 8'hA5 || received[1] !== 8'h5A ||
            received[2] !== 8'h81 || received[3] !== 8'h00 ||
            received[4] !== 8'h01 || received[5] !== 8'h02 ||
            received[6] !== 8'hA8 || received[7] !== 8'h49 ||
            led0 !== 1'b1)
            $fatal(1, "CRC16 PING response mismatch");

        send_ping(8'h00, 8'h00, 8'h00);
        #750000;
        if (received_count != 8 || led0 !== 1'b1)
            $fatal(1, "Bad CRC16 was accepted");

        send_byte(8'h00); // parser must skip unrelated input
        send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h02);
        send_byte(8'h55); send_byte(8'h00);
        send_byte(8'hEF); send_byte(8'h50);
        wait (received_count == 17);
        if (received[8] !== 8'hA5 || received[9] !== 8'h5A ||
            received[10] !== 8'h82 || received[11] !== 8'h55 ||
            received[12] !== 8'h02 || received[13] !== 8'h09 ||
            received[14] !== 8'h77 || received[15] !== 8'hAA ||
            received[16] !== 8'h64 || led0 !== 1'b0)
            $fatal(1, "CRC16 XADC response mismatch");

        send_ping(8'h10, 8'h2D, 8'hC0);
        send_ping(8'h11, 8'h2C, 8'h50);
        send_ping(8'h12, 8'h2C, 8'hA0);
        send_ping(8'h13, 8'h2D, 8'h30);
        wait (received_count == 49);
        for (j = 0; j < 4; j = j + 1) begin
            case (j)
                0: begin expected_lo = 8'hA9; expected_hi = 8'h8C; end
                1: begin expected_lo = 8'hF8; expected_hi = 8'h4C; end
                2: begin expected_lo = 8'h08; expected_hi = 8'h4C; end
                3: begin expected_lo = 8'h59; expected_hi = 8'h8C; end
            endcase
            if (received[17+j*8] !== 8'hA5 ||
                received[18+j*8] !== 8'h5A ||
                received[19+j*8] !== 8'h81 ||
                received[20+j*8] !== (8'h10+j) ||
                received[21+j*8] !== 8'h01 ||
                received[22+j*8] !== 8'h02 ||
                received[23+j*8] !== expected_lo ||
                received[24+j*8] !== expected_hi)
                $fatal(1, "CRC16 queued frame mismatch at %0d", j);
        end
        $display("PASS: course CRC16 framing, corrupt rejection, XADC, four queued frames");
        $finish;
    end

    initial begin
        #12000000;
        $fatal(1, "CRC16 frame simulation timeout");
    end
endmodule
