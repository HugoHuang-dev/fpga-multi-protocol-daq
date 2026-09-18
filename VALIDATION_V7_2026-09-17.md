# v7 four-channel XADC board capture (2026-09-17)

The Davinci Artix-7 board was programmed with `releases/xadc_four_channel_v7.bit`. A five-second automated capture ran through `host/stream_monitor.py` on COM10 at 115200 8N1. The serial utility separately showed PING protocol version `03`, `TYPE=91` four-channel frames, and the STOP acknowledgment. The raw bytes are in [v7 short-capture fixture](fixtures/v7_short_uart.bin), with statistics in [capture_v7.json](capture_v7.json).

| Metric | Result |
| --- | ---: |
| Measured duration | 5.012 s |
| Bytes received | 12,849 |
| Valid `TYPE=91` sample frames | 313 |
| Total sample records | 5,008 |
| Temperature / VCCINT / VCCAUX / VCCBRAM | 1,252 each |
| Received sample-frame rate | 62.451 frames/s |
| CRC errors / invalid lengths / invalid sample records | 0 / 0 / 0 |
| Sequence gaps / cumulative drop-count increase | 0 / 0 |
| START / STOP acknowledgments | Both received |

The four channel ranges were die temperature 32.36–35.067 °C, VCCINT 1.002–1.009 V, VCCAUX 1.798–1.808 V, and VCCBRAM 1.001–1.009 V. With 16 records per sample frame, `313 × 16 = 5,008`. Each frame is 41 bytes, and two command acknowledgments are eight bytes each: `313 × 41 + 2 × 8 = 12,849`, matching the raw file length. Offline parsing reproduced the counts, ranges, and error statistics:

```powershell
py -3 .\host\stream_monitor.py --input .\fixtures\v7_short_uart.bin
```

Raw-file SHA-256: `404C84B036587CE344E03719A74CC84C9C71B250B619F866B7EAF528750F33EC`.

This board capture exercises the four internal XADC measurements, batch framing, CRC-16, FIFO, and UART. No CRC error, sequence gap, or FPGA-reported drop was detected in five seconds. The separate v6 100-second temperature stream is in [v6 validation](VALIDATION_2026-09-17.md).
