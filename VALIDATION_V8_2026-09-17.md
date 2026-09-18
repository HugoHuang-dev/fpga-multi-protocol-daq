# v8 four-channel XADC + RTC board capture (2026-09-17)

After programming `releases/xadc_rtc_v8.bit` on the Davinci Artix-7 board, USB UART at 115200 8N1 confirmed PCF8563 time-read response `87` and time-set acknowledgment `88`. `host/stream_monitor.py` then captured approximately five seconds. The raw stream is [v8 short-capture fixture](fixtures/v8_short_uart.bin) and the summary is [capture_v8.json](capture_v8.json). Raw-file SHA-256: `12D746C0A6F201E834A1980C41EE34C8DDB35F97BA4E70650331E8460C4BFB5C`.

| Metric | Result |
| --- | ---: |
| Measured duration | 5.005 s |
| Bytes received | 12,883 |
| Four-channel sample frames `91` / RTC markers `92` | 312 / 5 |
| Total sample records | 4,992 |
| Temperature / VCCINT / VCCAUX / VCCBRAM | 1,248 each |
| CRC, length, sample-record, and RTC-marker errors | All zero |
| Sequence gaps / cumulative drop-count increase | 0 / 0 |
| START / STOP acknowledgments | Both received |

The five RTC markers span `2026-09-17 20:09:18` to `20:09:22`, all with `voltage_low=false`. Their next-sample-frame sequence values are `62, 125, 187, 250, 56`. The final `250 → 56` transition is normal eight-bit wrap after 62 frames, not a lost frame. Channel ranges were temperature 32.729–35.313 °C, VCCINT 1.002–1.009 V, VCCAUX 1.798–1.808 V, and VCCBRAM 1.002–1.009 V.

Offline replay of the raw file reproduced the live frame counts, per-channel records, time markers, and error statistics:

```powershell
py -3 .\host\stream_monitor.py --input .\fixtures\v8_short_uart.bin
```

The byte count checks independently: `312 × 41 + 5 × 15 + 2 × 8 = 12,883`, covering sample frames, RTC markers, and START/STOP acknowledgments. The board RTC read/set, periodic markers, and four-channel transmission worked in this short capture. Markers provide a time anchor with approximately one-second resolution for sample batches. The subsequent long run is in the [v8 two-hour record](VALIDATION_FINAL_2026-09-18.md).
