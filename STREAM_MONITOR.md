# Continuous-acquisition monitor (v6–v8)

`host/stream_monitor.py` sends START/STOP automatically, saves the raw UART bytes, and counts valid sample frames, CRC errors, sequence gaps, and changes in the FPGA-reported cumulative drop counter. It parses v6 `TYPE=90` temperature frames, v7/v8 `TYPE=91` four-channel frames, and v8 `TYPE=92` RTC markers.

Corresponding bitstreams are `releases/eeprom_v6.bit` for v6, `releases/xadc_four_channel_v7.bit` for v7, and `releases/xadc_rtc_v8.bit` for v8. The monitor exclusively owns the serial port while running. From the project root:

```powershell
py -3 -m pip install pyserial
py -3 .\host\stream_monitor.py --port COM9 --duration 600 --raw capture_10min.bin --summary capture_10min.json
```

`COM9` was used for this example; identify the port in Device Manager for another setup. The tool sends START, collects data for 600 seconds, then sends STOP and waits for acknowledgment. `--duration` is measured in seconds. Keep the board, USB UART, and host powered throughout the test.

The script writes a raw `.bin` stream and `.json` summary. The raw stream can be parsed again offline:

```powershell
py -3 .\host\stream_monitor.py --input capture_10min.bin --summary replay.json
```

Start with START/STOP acknowledgments, valid sample frames, CRC errors, sequence gaps, and the FPGA-reported drop-count increase. v7 also reports counts and ranges for all four channels. The sample-frame sequence is eight bits and the FPGA drop counter is 16 bits; the monitor accounts for wrap modulo 256 and 65,536, respectively. `sample_frames_per_second` is the received batch-frame rate.

September board records: the v6 100-second stream in [v6 validation](VALIDATION_2026-09-17.md), the v7 four-channel short capture in [v7 validation](VALIDATION_V7_2026-09-17.md), the v8 five-second RTC capture in [v8 validation](VALIDATION_V8_2026-09-17.md), and the final two-hour run in [v8 long-run validation](VALIDATION_FINAL_2026-09-18.md).
