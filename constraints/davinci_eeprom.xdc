# -----------------------------------------------------------------------------
# Hugo's FPGA Project
# -----------------------------------------------------------------------------
# Author  : sunmingyin.huang@haw-hamburg.de
# Project : FPGA-Based Multi-Source Data Acquisition and Host Communication System
# File    : davinci_eeprom.xdc
# Module  : Vivado constraints
# Created : 2026-06-16
# Revised : 2026-09-17
# Editor  : Sublime Text 3 (Build 3211), Tab Size (4)
# -----------------------------------------------------------------------------

create_clock -period 20.000 -name sys_clk [get_ports clkin_50m]
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS33} [get_ports clkin_50m]
set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS33} [get_ports rst_n]
set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS33} [get_ports uart_rxd]
set_property -dict {PACKAGE_PIN T6 IOSTANDARD LVCMOS33} [get_ports uart_txd]
set_property -dict {PACKAGE_PIN R2 IOSTANDARD LVCMOS33} [get_ports led0]
set_property -dict {PACKAGE_PIN R6 IOSTANDARD LVCMOS33} [get_ports iic_scl]
set_property -dict {PACKAGE_PIN T4 IOSTANDARD LVCMOS33} [get_ports iic_sda]
