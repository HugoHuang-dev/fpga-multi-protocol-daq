# ModelSim behavioral simulation for the v8 project

After generating the v8 project with `create_rtc_project.tcl`, run `configure_modelsim_v8.tcl` to add the testbenches under `Simulation Sources / sim_1`. ModelSim is the selected simulator, `tb_top_rtc_uart` is the default simulation top, and the run time is 50 ms. The synthesis top remains `top_rtc`. [configure_modelsim_v8.tcl](configure_modelsim_v8.tcl) reproduces this setup.

## Run from the Vivado GUI

1. Open `vivado_rtc/project1_uart_rtc.xpr` and confirm that the simulation sources belong to `sim_1`.
2. In **Sources**, select **Simulation Sources** and expand `sim_1`. Confirm `tb_top_rtc_uart` as the top. It instantiates the actual design top, `top_rtc`.
3. Use **Flow Navigator → Simulation → Run Simulation → Run Behavioral Simulation**. Vivado compiles RTL and testbench, then launches ModelSim. Wait for `PASS: UART RTC set/read, shared I2C, periodic time marker` in the ModelSim **Transcript**. The testbench ends with `$finish` at approximately 12.42 ms.
4. In ModelSim **Structure**, **click `dut` under `tb_top_rtc_uart`**; merely expanding the left-hand `+` does not select the instance. **Objects** then shows internal `top_rtc` signals. Select `rtc_start`, `rtc_done`, `rtc_reply_type`, and `streaming` and choose **Add to Wave**. The testbench-level `clk`, `uart_rxd`, `uart_txd`, `iic_scl`, and `iic_sda` appear when `tb_top_rtc_uart` is selected. Alternatively, enter `add wave sim:/tb_top_rtc_uart/dut/rtc_start sim:/tb_top_rtc_uart/dut/rtc_done sim:/tb_top_rtc_uart/dut/rtc_reply_type sim:/tb_top_rtc_uart/dut/streaming` in Transcript. Zoom into a UART or I²C transaction to see details; the 50 MHz clock appears as a solid bar at long time scales.

## Two other system tests

Set the corresponding testbench as the top under **Simulation Sources** and relaunch Behavioral Simulation, or run in the Vivado **Tcl Console**:

```tcl
set_property top tb_top_rtc_stream [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
```

Expect `PASS: bad CRC rejected, START, two 16-sample batches, CRC, UART, STOP`. This connectivity test covers four-channel records, CRC, UART, and START/STOP, and runs for approximately 41.06 ms.

EEPROM test:

```tcl
set_property top tb_top_rtc_eeprom [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
```

Expect `PASS: UART/CRC -> EEPROM read/write/read, NACK error, PING retained` at approximately 18.73 ms. Afterward, run `set_property top tb_top_rtc_uart [get_filesets sim_1]` to restore the default testbench.

Close the previous ModelSim instance before switching testbenches so its WLF waveform log is released. After a testbench executes `$finish`, Transcript may show `Break in Module`; use the corresponding `PASS` line to confirm the test result.

## Test setup

`sim/xadc_multichannel_stub.v` supplies deterministic four-channel inputs, and `sim/fifo_w8xd128_stub.v` models FIFO interface behavior. The tests focus on control logic, protocol framing, and handshakes between modules. The board UART and MATLAB tests record actual XADC measurements and RTC time.

All three system tests produced their PASS lines in ModelSim 10.6c on 2026-09-18; `tb_top_rtc_uart` was also launched from the Vivado project. To maintain ModelSim compatibility, three cross-block signal declarations in `rtl/top_rtc.v` were moved before their first use, without changing the logic.
