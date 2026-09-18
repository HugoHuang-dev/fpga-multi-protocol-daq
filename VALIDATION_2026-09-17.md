# v6 continuous temperature-stream board test (2026-09-17)

After programming `eeprom_v6.bit` onto the Davinci Artix-7 board, `host/stream_monitor.py --port COM10 --duration 100` sent START, captured the UART stream, and sent STOP at 115200, 8N1. The raw stream is `capture_10min.bin` and its summary is `capture_10min.json`. The actual run lasted **100.006 seconds**.

| Metric | Result |
| --- | ---: |
| START / STOP acknowledgments | One frame each |
| Valid temperature batch frames | 6,250, with 16 temperature records per frame |
| Temperature records received | 100,000 |
| Mean received batch-frame rate | 62.496 frames/s |
| CRC errors / invalid lengths / bytes discarded during resynchronization | 0 / 0 / 0 |
| Sequence gaps / FPGA-reported drop-count increase | 0 / 0 |
| On-chip temperature range | 32.61–35.68 °C |

The raw file is 256,266 bytes, exactly `6250 × 41 + 2 × 8` for batch frames and two acknowledgment frames. Offline replay of the `.bin` file produced the same frame and error counts. SHA-256: `C69CEFEA4DA24AC26EE38828ECA264D2237147AA8F423EFE55848DF8630A28BA`.

Over 100 seconds, the UART received 100,000 on-chip temperature records. Frame CRC, sequence continuity, and FPGA drop reporting were normal. The rate was approximately 1,000 records/s, matching the v6 timed-write cadence.
