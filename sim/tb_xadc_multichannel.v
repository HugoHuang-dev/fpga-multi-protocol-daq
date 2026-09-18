// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : tb_xadc_multichannel.v
// Module  : XADC, tb_xadc_multichannel
// Created : 2026-06-27
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

// DRP-level stand-in: each EOC identifies one sensor register; DRDY returns
// its 16-bit status word on the following clock. No analog behavior is modeled.
module XADC #(
    parameter INIT_40=0, INIT_41=0, INIT_42=0, INIT_48=0, INIT_49=0,
    parameter SIM_DEVICE="7SERIES"
)(
    input DCLK, input [6:0] DADDR, input DEN, input [15:0] DI, input DWE,
    input RESET, input CONVST, input CONVSTCLK, input [15:0] VAUXP,
    input [15:0] VAUXN, input VP, input VN,
    output reg [15:0] DO, output reg DRDY, output reg EOC,
    output reg [4:0] CHANNEL,
    output [7:0] ALM, output BUSY, EOS, JTAGBUSY, JTAGLOCKED,
    JTAGMODIFIED, OT, output [4:0] MUXADDR
);
    assign {ALM,BUSY,EOS,JTAGBUSY,JTAGLOCKED,JTAGMODIFIED,OT,MUXADDR}=0;
    reg [1:0] phase, sensor_index;
    always @(posedge DCLK) begin
        if (RESET) begin
            DO<=0; DRDY<=0; EOC<=0; CHANNEL<=0;
            phase<=0; sensor_index<=0;
        end else begin
            EOC<=0; DRDY<=0;
            if (phase==3) begin
                case(sensor_index)
                    0: CHANNEL<=5'h00;
                    1: CHANNEL<=5'h01;
                    2: CHANNEL<=5'h02;
                    3: CHANNEL<=5'h06;
                endcase
                EOC<=1;
                sensor_index<=sensor_index+1'b1;
                phase<=0;
            end else phase<=phase+1'b1;
            if (DEN) begin
                if (DADDR!={2'b00,CHANNEL}) $fatal(1,"DRP address/channel mismatch");
                case(DADDR)
                    7'h00: DO<=16'h9770;
                    7'h01: DO<=16'h5550;
                    7'h02: DO<=16'h9990;
                    7'h06: DO<=16'h5560;
                    default: $fatal(1,"unexpected DRP address %02x",DADDR);
                endcase
                DRDY<=1;
            end
        end
    end
endmodule

module tb_xadc_multichannel;
    reg clk=0, rst=1;
    wire [11:0] temperature, vccint, vccaux, vccbram;
    wire [3:0] valid_mask;
    always #10 clk=~clk;
    xadc_multichannel dut(.clk(clk), .rst(rst), .temperature(temperature),
        .vccint(vccint), .vccaux(vccaux), .vccbram(vccbram),
        .valid_mask(valid_mask));
    initial begin
        #100; rst=0;
        wait(valid_mask==4'hF);
        @(negedge clk);
        if(temperature!==12'h977 || vccint!==12'h555 ||
           vccaux!==12'h999 || vccbram!==12'h556)
            $fatal(1,"sensor DRP mapping wrong");
        $display("PASS: XADC DRP requests and four sensor status registers");
        $finish;
    end
    initial begin #5000; $fatal(1,"XADC channel timeout: valid=%b",valid_mask); end
endmodule
