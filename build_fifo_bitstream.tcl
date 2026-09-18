# -----------------------------------------------------------------------------
# Hugo's FPGA Project
# -----------------------------------------------------------------------------
# Author  : sunmingyin.huang@haw-hamburg.de
# Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
# File    : build_fifo_bitstream.tcl
# Module  : Vivado project automation
# Created : 2026-05-18
# Revised : 2026-09-17
# Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
# -----------------------------------------------------------------------------

set script_dir [file dirname [file normalize [info script]]]
open_project [file join $script_dir vivado_fifo project1_uart_fifo.xpr]
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
set run_status [get_property STATUS [get_runs impl_1]]
puts "Implementation status: $run_status"
if {![string match "write_bitstream Complete*" $run_status]} {
    error "Bitstream generation did not complete"
}
puts "Bitstream: [file join $script_dir vivado_fifo project1_uart_fifo.runs impl_1 top.bit]"
