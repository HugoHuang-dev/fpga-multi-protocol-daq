# -----------------------------------------------------------------------------
# Hugo's FPGA Project
# -----------------------------------------------------------------------------
# Author  : sunmingyin.huang@haw-hamburg.de
# Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
# File    : create_project.tcl
# Module  : Vivado project automation
# Created : 2026-05-12
# Revised : 2026-09-17
# Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
# -----------------------------------------------------------------------------

set script_dir [file dirname [file normalize [info script]]]
create_project project1_uart_xadc [file join $script_dir vivado_xadc] -part xc7a35tfgg484-2 -force
add_files [glob [file join $script_dir rtl *.v]]
add_files -fileset constrs_1 [file join $script_dir constraints davinci_uart.xdc]
set_property top top [current_fileset]
update_compile_order -fileset sources_1
puts "Project created: [file join $script_dir vivado_xadc project1_uart_xadc.xpr]"
