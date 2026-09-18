// -----------------------------------------------------------------------------
// Hugo's FPGA Project
// -----------------------------------------------------------------------------
// Author  : sunmingyin.huang@haw-hamburg.de
// Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
// File    : crc16_d8.v
// Module  : crc16_d8
// Created : 2026-05-25
// Revised : 2026-09-17
// Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
// -----------------------------------------------------------------------------

module crc16_d8(
	input  wire			  clk,
	input  wire           reset,

	input  wire 		   crc_din_vld, // Input byte valid
	input  wire [7:0]      crc_din,    // Input byte for CRC update
	output wire  [15:0]    crc_dout_f,   // Current CRC value
	input  wire            crc_done    // Reset CRC after final byte
    );


wire [7:0] crc_din_f; // Reverse the input bit order
reg  [15:0] crc_dout;
assign crc_din_f = {crc_din[0],crc_din[1],crc_din[2],crc_din[3],crc_din[4],crc_din[5],crc_din[6],crc_din[7]};

// Reverse the output bit order
assign crc_dout_f = {crc_dout[0],crc_dout[1],crc_dout[2],crc_dout[3],crc_dout[4],crc_dout[5],crc_dout[6],crc_dout[7],
                     crc_dout[8],crc_dout[9],crc_dout[10],crc_dout[11],crc_dout[12],crc_dout[13],crc_dout[14],crc_dout[15]};
wire [15:0] crc_data;

assign   crc_data[0] = crc_din_f[7] ^ crc_din_f[6] ^ crc_din_f[5] ^ crc_din_f[4] ^ crc_din_f[3] ^ crc_din_f[2] ^ crc_din_f[1] ^ crc_din_f[0] ^ crc_dout[8] ^ crc_dout[9] ^ crc_dout[10] ^ crc_dout[11] ^ crc_dout[12] ^ crc_dout[13] ^ crc_dout[14] ^ crc_dout[15];
assign   crc_data[1] = crc_din_f[7] ^ crc_din_f[6] ^ crc_din_f[5] ^ crc_din_f[4] ^ crc_din_f[3] ^ crc_din_f[2] ^ crc_din_f[1] ^ crc_dout[9] ^ crc_dout[10] ^ crc_dout[11] ^ crc_dout[12] ^ crc_dout[13] ^ crc_dout[14] ^ crc_dout[15];
assign   crc_data[2] = crc_din_f[1] ^ crc_din_f[0] ^ crc_dout[8] ^ crc_dout[9];
assign   crc_data[3] = crc_din_f[2] ^ crc_din_f[1] ^ crc_dout[9] ^ crc_dout[10];
assign   crc_data[4] = crc_din_f[3] ^ crc_din_f[2] ^ crc_dout[10] ^ crc_dout[11];
assign   crc_data[5] = crc_din_f[4] ^ crc_din_f[3] ^ crc_dout[11] ^ crc_dout[12];
assign   crc_data[6] = crc_din_f[5] ^ crc_din_f[4] ^ crc_dout[12] ^ crc_dout[13];
assign   crc_data[7] = crc_din_f[6] ^ crc_din_f[5] ^ crc_dout[13] ^ crc_dout[14];
assign   crc_data[8] = crc_din_f[7] ^ crc_din_f[6] ^ crc_dout[0] ^ crc_dout[14] ^ crc_dout[15];
assign   crc_data[9] = crc_din_f[7] ^ crc_dout[1] ^ crc_dout[15];
assign   crc_data[10] = crc_dout[2];
assign   crc_data[11] = crc_dout[3];
assign   crc_data[12] = crc_dout[4];
assign   crc_data[13] = crc_dout[5];
assign   crc_data[14] = crc_dout[6];
assign   crc_data[15] = crc_din_f[7] ^ crc_din_f[6] ^ crc_din_f[5] ^ crc_din_f[4] ^ crc_din_f[3] ^ crc_din_f[2] ^ crc_din_f[1] ^ crc_din_f[0] ^ crc_dout[7] ^ crc_dout[8] ^ crc_dout[9] ^ crc_dout[10] ^ crc_dout[11] ^ crc_dout[12] ^ crc_dout[13] ^ crc_dout[14] ^ crc_dout[15];




always @(posedge clk) begin
    if (reset)
       crc_dout <= 16'hffff;    // CRC-16/MODBUS initial value
    else if (crc_done)
       crc_dout <= 16'hffff;   // CRC-16/MODBUS initial value
    else if (crc_din_vld)begin
	   crc_dout <= crc_data ;
    end
end


endmodule
