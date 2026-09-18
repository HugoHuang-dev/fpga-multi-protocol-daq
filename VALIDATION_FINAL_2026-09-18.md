# v8 two-hour continuous-run record (2026-09-18)

The Davinci V2.1 / Artix-7 board was programmed with `releases/xadc_rtc_v8.bit`. `host/stream_monitor.py` ran on COM11 at 115200 8N1. It sent START, continuously received four-channel XADC batches and PCF8563 time markers, then sent STOP after 7,200 seconds. Both the command's `--duration 7200` and the summary's `duration_seconds` confirm a **two-hour** run.

| Metric | Measured result |
| --- | ---: |
| Duration | **7200.009 s** |
| Bytes received | **18,557,550** |
| `TYPE=91` four-channel sample frames | **449,989** (62.498 frames/s) |
| Total sample records | **7,199,824** |
| Temperature / VCCINT / VCCAUX / VCCBRAM | **1,799,956 each** |
| `TYPE=92` RTC markers | **7,199** |
| START / STOP acknowledgments | Both received |
| CRC errors / invalid lengths / discarded resynchronization bytes | **0 / 0 / 0** |
| Sample-frame sequence gaps / FPGA-reported drop-count increase | **0 / 0** |
| Invalid sample records / invalid RTC markers / trailing incomplete bytes | **0 / 0 / 0** |

Measured ranges: die temperature **32.606–36.421 °C**, VCCINT **1.000–1.011 V**, VCCAUX **1.796–1.811 V**, and VCCBRAM **1.000–1.011 V**. The logic rotates the channel recorded into the FIFO every 1 ms, giving approximately 250 records/s per channel.

The RTC markers span board-local time **2026-09-18 15:43:37** to **17:43:35**. Adjacent markers are one second apart; `voltage_low` and `century_bit` are false in every marker. Each `next_batch_seq` equals the number of received sample frames modulo 256. The 7,199 markers span 7,198 complete one-second intervals, with the count affected by the START/STOP boundaries. Comparing the host finish time with the final RTC marker suggests that the board clock was approximately **38–39 seconds behind** the host. This run validates time continuity; absolute time still requires clock setting.

The raw stream length matches the exact frame composition: `449,989 × 41 + 7,199 × 15 + 2 × 8 = 18,557,550` bytes. Offline replay of the `capture_v8_final_2h.bin` matched the `capture_v8_final_2h.json` for sample frames, four-channel records, RTC markers, START/STOP acknowledgments, and error counts. The full raw capture, live/replay JSON files, and terminal log are excluded from this source repository; the measured results and raw-stream hash are preserved here.

Raw-stream SHA-256: `12895637AC372D731DD061E35A5123A89D5A0846DC845C62393DB5C3CA8B54B9`.

Four-channel acquisition, periodic RTC markers, CRC-16 framing, and UART transmission ran throughout these two hours. The monitor detected no CRC, sequence, or FPGA sample-drop anomaly. The batch-frame rate is the rate received over UART; sample-record counts are the number of FPGA FIFO writes from on-chip XADC results.
