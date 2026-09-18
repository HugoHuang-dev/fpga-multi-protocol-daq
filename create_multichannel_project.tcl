# -----------------------------------------------------------------------------
# Hugo's FPGA Project
# -----------------------------------------------------------------------------
# Author  : sunmingyin.huang@haw-hamburg.de
# Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
# File    : create_multichannel_project.tcl
# Module  : Vivado project automation
# Created : 2026-06-27
# Revised : 2026-09-17
# Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
# -----------------------------------------------------------------------------

set script_dir [file dirname [file normalize [info script]]]
create_project project1_uart_multichannel [file join $script_dir vivado_multichannel] -part xc7a35tfgg484-2 -force
add_files [glob [file join $script_dir rtl *.v]]
add_files [file join $script_dir ip fifo_w8xd128.xci]
add_files -fileset constrs_1 [file join $script_dir constraints davinci_eeprom.xdc]
set_property top top_multichannel [current_fileset]
update_compile_order -fileset sources_1
puts "Project created: [file join $script_dir vivado_multichannel project1_uart_multichannel.xpr]"
