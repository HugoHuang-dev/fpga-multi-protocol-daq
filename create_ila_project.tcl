# -----------------------------------------------------------------------------
# Hugo's FPGA Project
# -----------------------------------------------------------------------------
# Author  : sunmingyin.huang@haw-hamburg.de
# Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
# File    : create_ila_project.tcl
# Module  : Vivado project automation
# Created : 2026-07-12
# Revised : 2026-09-18
# Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
# -----------------------------------------------------------------------------

# Create an isolated v8 ILA project without modifying the validated RTC project.
# Debug nets are attached to the synthesized design, so RTL stays identical.
set root [file dirname [file normalize [info script]]]
set debug_dir [file join $root debug_ila]
file mkdir $debug_dir
file copy -force [file join $root rtl top_rtc.v] [file join $debug_dir top_rtc_ila.v]
file copy -force [file join $root constraints davinci_eeprom.xdc] [file join $debug_dir davinci_ila.xdc]

create_project project1_uart_ila [file join $root vivado_ila] -part xc7a35tfgg484-2
foreach name {
    crc16_d8.v eeprom_iic_master.v pcf8563_iic_master.v sample_fifo.v
    uart_rx.v uart_send_fifo.v uart_tx.v xadc_multichannel.v
} {
    add_files [file join $root rtl $name]
}
add_files [file join $debug_dir top_rtc_ila.v]
add_files [file join $root ip fifo_w8xd128.xci]
add_files -fileset constrs_1 [file join $debug_dir davinci_ila.xdc]
set_property top top_rtc [get_filesets sources_1]
update_compile_order -fileset sources_1
puts "ILA project created: [file join $root vivado_ila project1_uart_ila.xpr]"
close_project
