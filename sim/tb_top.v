// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : tb_top.v
// Module  : tb_top
// Created : 2026-05-12
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_top;
    localparam integer BIT_NS = 8680; // 50 MHz / 115200 rounds to 434 clocks
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst_n = 0;
    reg uart_rxd = 1;
    wire uart_txd;
    wire led0;
    integer received_count = 0;
    reg [7:0] received [0:63];
    integer i;
    integer j;
    reg [7:0] expected_crc;
    reg [7:0] observed;

    top dut (.clkin_50m(clk), .rst_n(rst_n), .uart_rxd(uart_rxd),
             .uart_txd(uart_txd), .led0(led0));

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

    task ping_zero;
        begin
            send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h01);
            send_byte(8'h00); send_byte(8'h00); send_byte(8'h6B);
        end
    endtask

    // Independent bit-level monitor for FPGA serial output.
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
        #200;
        rst_n = 1;
        #1000;
        ping_zero();
        wait (received_count == 7);
        if (received[0] !== 8'hA5 || received[1] !== 8'h5A ||
            received[2] !== 8'h81 || received[3] !== 8'h00 ||
            received[4] !== 8'h01 || received[5] !== 8'h01 ||
            received[6] !== 8'h35 || led0 !== 1'b1)
            $fatal(1, "PING response or LED mismatch");

        #20000;
        send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h01);
        send_byte(8'h34); send_byte(8'h00); send_byte(8'hC6);
        wait (received_count == 14);
        if (received[7] !== 8'hA5 || received[8] !== 8'h5A ||
            received[9] !== 8'h81 || received[10] !== 8'h34 ||
            received[11] !== 8'h01 || received[12] !== 8'h01 ||
            received[13] !== 8'h7F || led0 !== 1'b0)
            $fatal(1, "Sequence response mismatch");

        #20000;
        send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h01);
        send_byte(8'h00); send_byte(8'h00); send_byte(8'h00);
        #700000;
        if (received_count != 14 || led0 !== 1'b0)
            $fatal(1, "Bad CRC was accepted");

        send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h02);
        send_byte(8'h55); send_byte(8'h00); send_byte(8'h9B);
        wait (received_count == 22);
        if (received[14] !== 8'hA5 || received[15] !== 8'h5A ||
            received[16] !== 8'h82 || received[17] !== 8'h55 ||
            received[18] !== 8'h02 || received[19] !== 8'h09 ||
            received[20] !== 8'h77 || received[21] !== 8'hC8 ||
            led0 !== 1'b1)
            $fatal(1, "XADC sample response mismatch");

        // Four commands arrive back-to-back without waiting for any reply.
        send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h01);
        send_byte(8'h10); send_byte(8'h00); send_byte(8'h3C);
        send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h01);
        send_byte(8'h11); send_byte(8'h00); send_byte(8'h29);
        send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h01);
        send_byte(8'h12); send_byte(8'h00); send_byte(8'h16);
        send_byte(8'hA5); send_byte(8'h5A); send_byte(8'h01);
        send_byte(8'h13); send_byte(8'h00); send_byte(8'h03);
        wait (received_count == 50);
        for (j = 0; j < 4; j = j + 1) begin
            case (j)
                0: expected_crc = 8'h97;
                1: expected_crc = 8'hFC;
                2: expected_crc = 8'h41;
                3: expected_crc = 8'h2A;
            endcase
            if (received[22 + j*7] !== 8'hA5 ||
                received[23 + j*7] !== 8'h5A ||
                received[24 + j*7] !== 8'h81 ||
                received[25 + j*7] !== (8'h10 + j) ||
                received[26 + j*7] !== 8'h01 ||
                received[27 + j*7] !== 8'h01 ||
                received[28 + j*7] !== expected_crc)
                $fatal(1, "FIFO burst response mismatch at frame %0d", j);
        end
        $display("PASS: PING, sequence, CRC rejection, XADC packet, four queued frames");
        $finish;
    end

    initial begin
        #12000000;
        $fatal(1, "Simulation timeout");
    end
endmodule
