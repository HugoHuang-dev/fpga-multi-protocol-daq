# -----------------------------------------------------------------------------
# Hugo's FPGA Project
# -----------------------------------------------------------------------------
# Author  : sunmingyin.huang@haw-hamburg.de
# Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
# File    : configure_modelsim_v8.tcl
# Module  : Vivado project automation
# Created : 2026-07-12
# Revised : 2026-09-18
# Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
# -----------------------------------------------------------------------------

# Add the existing v8 system testbenches to the Vivado 2018.3 RTC project.
# Run once with: vivado.bat -mode batch -source configure_modelsim_v8.tcl
set root [file dirname [file normalize [info script]]]
set project_file [file join $root vivado_rtc project1_uart_rtc.xpr]
open_project $project_file
set_property target_simulator ModelSim [current_project]

# The physical XADC and FIFO IP remain in synthesis/implementation. Behavioral
# models are used only for this deterministic, portable RTL simulation.
set required_rtl {
    crc16_d8.v eeprom_iic_master.v pcf8563_iic_master.v sample_fifo.v
    top_rtc.v uart_rx.v uart_send_fifo.v uart_tx.v
}
foreach file [glob [file join $root rtl *.v]] {
    set enabled [expr {[file tail $file] in $required_rtl}]
    set_property used_in_simulation $enabled [get_files $file]
}
set_property used_in_simulation false [get_files [file join $root ip fifo_w8xd128.xci]]

set sim_files [list \
    [file join $root sim xadc_multichannel_stub.v] \
    [file join $root sim fifo_w8xd128_stub.v] \
    [file join $root sim tb_top_rtc_uart.v] \
    [file join $root sim tb_top_rtc_stream.v] \
    [file join $root sim tb_top_rtc_eeprom.v]]
foreach file $sim_files {
    if {[llength [get_files -quiet $file]] == 0} {
        add_files -fileset sim_1 $file
    }
}
foreach file [lrange $sim_files 2 end] {
    set_property file_type SystemVerilog [get_files $file]
}
set_property top tb_top_rtc_uart [get_filesets sim_1]
set_property modelsim.simulate.runtime {50 ms} [get_filesets sim_1]
update_compile_order -fileset sim_1
puts "ModelSim target: [get_property target_simulator [current_project]]"
puts "Simulation top: [get_property top [get_filesets sim_1]]"
puts "ModelSim simulation properties:"
foreach name [list_property [get_filesets sim_1]] {
    if {[string match -nocase *modelsim* $name]} {
        puts "  $name = [get_property $name [get_filesets sim_1]]"
    }
}
close_project
