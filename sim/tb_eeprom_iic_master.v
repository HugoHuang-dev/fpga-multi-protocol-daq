// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : tb_eeprom_iic_master.v
// Module  : tb_eeprom_iic_master
// Created : 2026-06-16
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
module tb_eeprom_iic_master;
    reg clk=0, rst=1, start=0, read_not_write=0;
    reg [15:0] word_addr=0;
    reg [7:0] write_data=0;
    tri1 scl, sda;
    reg slave_low=0;
    assign sda = slave_low ? 1'b0 : 1'bz;
    wire busy, done, ack_error;
    wire [7:0] read_data;
    reg [7:0] memory_byte=8'h3C;
    reg [7:0] address_byte, high_byte, low_byte, data_byte;
    integer i, operations=0;
    always #10 clk=~clk;
    eeprom_iic_master #(.HALF_TICKS(25)) dut (
        .clk(clk), .rst(rst), .start(start), .read_not_write(read_not_write),
        .word_addr(word_addr), .write_data(write_data), .scl(scl), .sda(sda),
        .busy(busy), .done(done), .ack_error(ack_error), .read_data(read_data));
    task get_byte;
        output reg [7:0] value;
        integer k;
        begin
            value=0;
            for(k=7;k>=0;k=k-1) begin @(posedge scl); value[k]=sda; end
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
            if(scl !== 1'b1) $fatal(1,"START while SCL low");
        end
    endtask
    always begin
        wait(!rst);
        expect_start();
        get_byte(address_byte);
        if(address_byte!==8'hA0) $fatal(1,"wrong device write address %h",address_byte);
        ack_byte();
        get_byte(high_byte); ack_byte();
        get_byte(low_byte); ack_byte();
        if({high_byte,low_byte}!==16'h1FF0)
            $fatal(1,"wrong word address %h %h",high_byte,low_byte);
        if(read_not_write) begin
            expect_start();
            get_byte(address_byte);
            if(address_byte!==8'hA1) $fatal(1,"wrong device read address %h",address_byte);
            ack_byte();
            for(i=7;i>=0;i=i-1) begin
                slave_low=!memory_byte[i];
                @(posedge scl);
                @(negedge scl);
            end
            slave_low=0;
            @(posedge scl);
            if(sda!==1'b1) $fatal(1,"master did not NACK read byte");
        end else begin
            get_byte(data_byte); ack_byte();
            memory_byte=data_byte;
        end
        @(posedge sda);
        if(scl!==1'b1) $fatal(1,"STOP while SCL low");
        operations=operations+1;
    end
    task run_transaction;
        input read_mode;
        input [7:0] value;
        begin
            @(negedge clk);
            word_addr=16'h1FF0; write_data=value;
            read_not_write=read_mode; start=1;
            @(negedge clk); start=0;
            wait(done);
            if(ack_error) $fatal(1,"unexpected I2C NACK");
            if(read_mode && read_data!==value)
                $fatal(1,"read mismatch %h expected %h",read_data,value);
            @(negedge clk);
        end
    endtask
    initial begin
        #200; rst=0;
        run_transaction(0,8'hA6);
        run_transaction(1,8'hA6);
        if(operations!=2) $fatal(1,"operation count wrong");
        $display("PASS: EEPROM I2C write, repeated-start random read, ACK, open drain");
        $finish;
    end
    initial begin #2000000; $fatal(1,"EEPROM I2C timeout state=%0d",dut.state); end
endmodule
