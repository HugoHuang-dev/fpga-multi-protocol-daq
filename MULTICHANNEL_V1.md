# v7: Four-channel on-chip XADC acquisition

Building on v6's UART, CRC-16, two FIFOs, and I²C EEPROM, v7 extends the data source to FPGA die temperature, VCCINT, VCCAUX, and VCCBRAM. XADC automatically scans the four internal channels. Once valid readings are available, the logic records one every 1 ms in the order temperature → VCCINT → VCCAUX → VCCBRAM. The total record rate is 1,000/s, or **approximately 250/s per channel**.

The path remains a 16-bit × 64 sample FIFO → one frame per 16 records → CRC-16 → UART byte FIFO → 115200 8N1 USB serial. Each 16-bit record is encoded as `CHANNEL[1:0] | 00 | RAW[11:0]`. Channel IDs 0/1/2/3 map to the four measurements above. Voltage conversion is `raw × 3 / 4096` V; temperature conversion remains `raw × 503.975 / 4096 − 273.15` °C. The single temperature read command `02`, EEPROM commands `05`/`06`, START `03`, and STOP `04` remain available.

Batch frames use the new `TYPE=91` so the old `TYPE=90` temperature-stream parser cannot mistake voltage records for temperatures. The frame is still `A5 5A | TYPE | SEQ | LEN | PAYLOAD | CRC_LO | CRC_HI`. With `LEN=34`, the first two payload bytes are the big-endian cumulative drop count, followed by 16 big-endian 16-bit records (32 bytes). Each batch frame is 41 bytes. PING now reports protocol version `03`.

## Board test

Run `create_multichannel_project.tcl` and `build_multichannel_bitstream.tcl` in Vivado 2018.3, then program the generated v7 bitstream. Set the serial utility to 115200, 8N1, Hex. Send `A5 5A 01 00 00 20 00` and expect `A5 5A 81 00 01 03 69 89`. Then send `A5 5A 03 00 00 81 C0`; after the START acknowledgment, `A5 5A 91 ...` batch frames should appear. Send `A5 5A 04 00 00 30 01` to stop.

Alternatively, close the serial utility and run a short automated capture of approximately five seconds:

```powershell
py -3 .\host\stream_monitor.py --port COM10 --duration 5 --raw capture_v7.bin --summary capture_v7.json
```

`COM10` was the port used for this board test; determine the port for another setup in Device Manager. The summary's `records_by_channel` gives counts for each internal measurement; `channel_ranges` gives temperature and voltage ranges. CRC, sequence, and drop statistics for this capture are below. `host/protocol_crc16.py decode` decodes individual `TYPE=91` frames; EEPROM commands are described in [EEPROM_V1.md](EEPROM_V1.md).

## Validation

Tests passed for XADC DRP channel mapping, continuous UART frames, EEPROM read/write, and host decoding. Vivado 2018.3 generated the bitstream with 14.546 ns WNS against the 50 MHz constraint. A five-second September board capture received 5,008 records, 1,252 per channel, with zero CRC errors, sequence gaps, or reported drop-count increase. Raw data and recalculation steps are in the [v7 board record](VALIDATION_V7_2026-09-17.md).
