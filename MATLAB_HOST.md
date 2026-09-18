# MATLAB host application (v8)

`matlab/project1_host.m` reads v8 UART frames, checks CRC-16, decodes four-channel XADC records and RTC time markers, plots the four channels, and exports CSV, JSON, and the raw bytes of a live capture.

## Step 1: Offline replay

Open `matlab/run_replay_demo.m` in MATLAB and click **Run**. The script replays `fixtures/v8_short_uart.bin`, displays all four channel plots, and writes `samples.csv`, `rtc_markers.csv`, and `summary.json` under `matlab_output/`. The expected result is **312 batch frames, 4,992 records, five RTC markers, and zero CRC errors**, with 1,248 records per channel. RTC markers have second resolution; individual sample records have no hardware timestamp. The horizontal axis is the record index within each channel.

From the project root, the same replay can be started in the MATLAB Command Window:

```matlab
addpath('matlab')
[report, samples] = project1_host("replay", "fixtures/v8_short_uart.bin", Plot=true, OutputDir="matlab_output");
```

## Step 2: Live board capture

Live acquisition uses `releases/xadc_rtc_v8.bit` and gives MATLAB exclusive access to the serial port. Use `serialportlist("available")` to find the port; the September board test used `COM10`:

```matlab
[report, samples] = project1_host("live", "COM10", ...
    Duration=5, Baud=115200, Plot=true, OutputDir="matlab_live_5s");
```

The program sends START (`TYPE=03`), refreshes the four plots during acquisition, sends STOP (`TYPE=04`) when the duration expires, and waits up to two seconds for the STOP acknowledgment. The output directory's `capture.bin` can be replayed offline. `samples.csv` retains the raw 12-bit codes and converted engineering values; `rtc_markers.csv` retains one-second RTC markers. `summary.json` reports CRC errors, invalid frames, sample sequence gaps, the FPGA-reported FIFO drop count, invalid samples or RTC markers, and START/STOP acknowledgments.

The plots show the FPGA **die temperature and three internal supply rails**. The observed frame rate is calculated from the live duration and received frame count. RTC markers carry board-local calendar time without time-zone information.

## Validation

`test_project1_host` compares MATLAB decoding with the v8 board capture, checks CSV/JSON export and plotting, and corrupts one frame to verify CRC-error and sequence-gap detection. Results of the September five-second live capture are in the [MATLAB board record](VALIDATION_MATLAB_2026-09-17.md).
