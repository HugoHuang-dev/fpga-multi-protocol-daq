# -----------------------------------------------------------------------------
# Hugo's FPGA Project
# -----------------------------------------------------------------------------
# Author  : sunmingyin.huang@haw-hamburg.de
# Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
# File    : ila_core.xdc
# Module  : Vivado constraints
# Created : 2026-07-12
# Revised : 2026-09-18
# Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
# -----------------------------------------------------------------------------

set_property MARK_DEBUG true [get_nets request_valid]
set_property MARK_DEBUG true [get_nets {request_type_reg_n_0_[0]}]
set_property MARK_DEBUG true [get_nets {request_type_reg_n_0_[1]}]
set_property MARK_DEBUG true [get_nets {request_type_reg_n_0_[2]}]
set_property MARK_DEBUG true [get_nets {request_type_reg_n_0_[3]}]
set_property MARK_DEBUG true [get_nets {request_type_reg_n_0_[4]}]
set_property MARK_DEBUG true [get_nets {request_type_reg_n_0_[5]}]
set_property MARK_DEBUG true [get_nets {request_type_reg_n_0_[6]}]
set_property MARK_DEBUG true [get_nets {request_type_reg_n_0_[7]}]
set_property MARK_DEBUG true [get_nets streaming]
set_property MARK_DEBUG true [get_nets rtc_reply_valid]
set_property MARK_DEBUG true [get_nets {send_state_reg_n_0_[0]}]
set_property MARK_DEBUG true [get_nets {send_state_reg_n_0_[1]}]
set_property MARK_DEBUG true [get_nets {rx_data[0]}]
set_property MARK_DEBUG true [get_nets {rx_data[1]}]
set_property MARK_DEBUG true [get_nets {rx_data[2]}]
set_property MARK_DEBUG true [get_nets {rx_data[3]}]
set_property MARK_DEBUG true [get_nets {rx_data[4]}]
set_property MARK_DEBUG true [get_nets {rx_data[5]}]
set_property MARK_DEBUG true [get_nets {rx_data[6]}]
set_property MARK_DEBUG true [get_nets {rx_data[7]}]
set_property MARK_DEBUG true [get_nets rx_inst/rx_valid]
create_debug_core ila_p1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores ila_p1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores ila_p1]
set_property C_ADV_TRIGGER false [get_debug_cores ila_p1]
set_property C_DATA_DEPTH 8192 [get_debug_cores ila_p1]
set_property C_EN_STRG_QUAL false [get_debug_cores ila_p1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores ila_p1]
set_property C_TRIGIN_EN false [get_debug_cores ila_p1]
set_property C_TRIGOUT_EN false [get_debug_cores ila_p1]
set_property port_width 1 [get_debug_ports ila_p1/clk]
connect_debug_port ila_p1/clk [get_nets [list clkin_50m_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports ila_p1/probe0]
set_property port_width 1 [get_debug_ports ila_p1/probe0]
connect_debug_port ila_p1/probe0 [get_nets [list request_valid]]
create_debug_port ila_p1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports ila_p1/probe1]
set_property port_width 8 [get_debug_ports ila_p1/probe1]
connect_debug_port ila_p1/probe1 [get_nets [list {request_type_reg_n_0_[0]} {request_type_reg_n_0_[1]} {request_type_reg_n_0_[2]} {request_type_reg_n_0_[3]} {request_type_reg_n_0_[4]} {request_type_reg_n_0_[5]} {request_type_reg_n_0_[6]} {request_type_reg_n_0_[7]}]]
create_debug_port ila_p1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports ila_p1/probe2]
set_property port_width 1 [get_debug_ports ila_p1/probe2]
connect_debug_port ila_p1/probe2 [get_nets [list streaming]]
create_debug_port ila_p1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports ila_p1/probe3]
set_property port_width 1 [get_debug_ports ila_p1/probe3]
connect_debug_port ila_p1/probe3 [get_nets [list rtc_reply_valid]]
create_debug_port ila_p1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports ila_p1/probe4]
set_property port_width 2 [get_debug_ports ila_p1/probe4]
connect_debug_port ila_p1/probe4 [get_nets [list {send_state_reg_n_0_[0]} {send_state_reg_n_0_[1]}]]
create_debug_port ila_p1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports ila_p1/probe5]
set_property port_width 8 [get_debug_ports ila_p1/probe5]
connect_debug_port ila_p1/probe5 [get_nets [list {rx_data[0]} {rx_data[1]} {rx_data[2]} {rx_data[3]} {rx_data[4]} {rx_data[5]} {rx_data[6]} {rx_data[7]}]]
create_debug_port ila_p1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports ila_p1/probe6]
set_property port_width 1 [get_debug_ports ila_p1/probe6]
connect_debug_port ila_p1/probe6 [get_nets [list rx_inst/rx_valid]]
set_property C_CLK_INPUT_FREQ_HZ 50000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clkin_50m_IBUF_BUFG]
