# -----------------------------------------------------------------------------
# Hugo's FPGA Project
# -----------------------------------------------------------------------------
# Author  : sunmingyin.huang@haw-hamburg.de
# Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
# File    : insert_ila_debug.tcl
# Module  : Vivado project automation
# Created : 2026-07-12
# Revised : 2026-09-18
# Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
# -----------------------------------------------------------------------------

# Run after synthesis of vivado_ila. Insert ILA in the synthesized netlist.
set root [file dirname [file normalize [info script]]]
open_project [file join $root vivado_ila project1_uart_ila.xpr]
open_run synth_1

proc one_net {name} {
    set result [get_nets -quiet $name]
    if {[llength $result] != 1} { error "Expected one net '$name', got: $result" }
    return $result
}
proc attach_probe {index nets} {
    if {$index > 0} { create_debug_port ila_p1 probe }
    set port [get_debug_ports ila_p1/probe$index]
    set_property port_width [llength $nets] $port
    set_property MARK_DEBUG true $nets
    connect_debug_port $port $nets
    puts "ILA probe$index: $nets"
}

create_debug_core ila_p1 ila
set core [get_debug_cores ila_p1]
set_property C_DATA_DEPTH 8192 $core
set_property C_TRIGIN_EN false $core
set_property C_TRIGOUT_EN false $core
set_property C_ADV_TRIGGER false $core
set_property C_INPUT_PIPE_STAGES 0 $core
connect_debug_port ila_p1/clk [one_net clkin_50m_IBUF_BUFG]

attach_probe 0 [list [one_net request_valid]]
set type_bits {}
for {set i 0} {$i < 8} {incr i} {
    lappend type_bits [one_net [format {request_type_reg_n_0_[%d]} $i]]
}
attach_probe 1 $type_bits
attach_probe 2 [list [one_net streaming]]
attach_probe 3 [list [one_net rtc_reply_valid]]
set send_bits {}
for {set i 0} {$i < 2} {incr i} {
    lappend send_bits [one_net [format {send_state_reg_n_0_[%d]} $i]]
}
attach_probe 4 $send_bits
set rx_bits {}
for {set i 0} {$i < 8} {incr i} {
    lappend rx_bits [one_net [format {rx_data[%d]} $i]]
}
attach_probe 5 $rx_bits
attach_probe 6 [list [one_net rx_inst/rx_valid]]

save_constraints
puts "ILA debug core inserted and saved. Reopen synthesized design to inspect probes."
close_project
