// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : tb_pcf8563_iic_master.v
// Module  : tb_pcf8563_iic_master
// Created : 2026-07-05
// Revised : 2026-09-18
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
module tb_pcf8563_iic_master;
    reg clk=0, rst=1, start=0, write_not_read=0;
    reg [55:0] write_data=56'h12345607120926;
    wire [55:0] read_data;
    tri1 scl, sda;
    reg slave_low=0;
    assign sda = slave_low ? 1'b0 : 1'bz;
    wire busy, done, ack_error;
    reg [55:0] stored=56'h00000000000000;
    reg [7:0] got;
    integer i, k, operations=0;
    always #10 clk=~clk;
    pcf8563_iic_master #(.HALF_TICKS(25)) dut (
        .clk(clk), .rst(rst), .start(start),
        .write_not_read(write_not_read), .write_data(write_data),
        .scl(scl), .sda(sda), .busy(busy), .done(done),
        .ack_error(ack_error), .read_data(read_data));

    task get_byte;
        output reg [7:0] value;
        integer j;
        begin
            value=0;
            for(j=7;j>=0;j=j-1) begin @(posedge scl); value[j]=sda; end
        end
    endtask
    task ack_byte;
        begin
            @(negedge scl); slave_low=1;
            @(posedge scl);
            @(negedge scl); slave_low=0;
        end
    endtask
    task expect_start;
        begin
            @(negedge sda);
            if (scl!==1'b1) $fatal(1,"START with SCL low");
        end
    endtask
    task send_byte;
        input [7:0] value;
        input last;
        integer j;
        begin
            for(j=7;j>=0;j=j-1) begin
                slave_low=!value[j];
                @(posedge scl); @(negedge scl);
            end
            slave_low=0;
            @(posedge scl);
            if (sda !== (last ? 1'b1 : 1'b0))
                $fatal(1,"master ACK/NACK wrong at byte %0d",i);
            if (!last) @(negedge scl);
        end
    endtask

    always begin
        wait(!rst);
        expect_start();
        get_byte(got);
        if(got!==8'hA2) $fatal(1,"RTC write address %h",got);
        ack_byte();
        get_byte(got);
        if(got!==8'h02) $fatal(1,"RTC pointer %h",got);
        ack_byte();
        if(write_not_read) begin
            for(i=0;i<7;i=i+1) begin
                get_byte(got);
                stored[55-i*8 -:8]=got;
                ack_byte();
            end
        end else begin
            expect_start();
            get_byte(got);
            if(got!==8'hA3) $fatal(1,"RTC read address %h",got);
            ack_byte();
            for(i=0;i<7;i=i+1)
                send_byte(stored[55-i*8 -:8],i==6);
        end
        @(posedge sda);
        if(scl!==1'b1) $fatal(1,"STOP with SCL low");
        operations=operations+1;
    end

    task run_transaction;
        input write_mode;
        begin
            @(negedge clk); write_not_read=write_mode; start=1;
            @(negedge clk); start=0;
            wait(done);
            if(ack_error) $fatal(1,"unexpected RTC NACK");
            if(!write_mode && read_data!==write_data)
                $fatal(1,"RTC read %h expected %h",read_data,write_data);
            @(negedge clk);
        end
    endtask
    initial begin
        #200; rst=0;
        run_transaction(1);
        run_transaction(0);
        if(operations!=2) $fatal(1,"operation count %0d",operations);
        $display("PASS: PCF8563 7-byte write/read, repeated START, ACK/NACK");
        $finish;
    end
    initial begin #4000000; $fatal(1,"RTC timeout state=%0d",dut.state); end
endmodule
