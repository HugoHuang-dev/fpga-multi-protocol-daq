# v5: Continuous on-chip XADC temperature stream

Data path: XADC die-temperature register → **16-bit × 64 sample FIFO** → 16-sample batch framing with CRC-16 → 8-bit × 128-byte UART TX FIFO → USB UART → PC. Both FIFOs and the control logic run in the board's 50 MHz clock domain.

The FPGA records the latest valid XADC temperature reading every 50,000 clock cycles, giving 1,000 records/s. If the sample FIFO is full, it discards the current record and increments a 16-bit cumulative drop counter. The host handles counter wrap modulo 65,536.

## Board procedure

Run `create_stream_project.tcl` and `build_stream_bitstream.tcl` in Vivado 2018.3, then program the generated v5 bitstream. Set the serial port to **115200, 8N1, no flow control**, with both TX and RX in Hex mode.

1. Clear the receive area and send START `A5 5A 03 00 00 81 C0`. Expect acknowledgment `A5 5A 83 00 01 01 E9 F0` first, followed by continuous `A5 5A 90 ...` frames after roughly 16 ms. If the utility displays one unbroken byte stream, parse each frame by `LEN`: a `90` frame is **41 bytes**.
2. After a few seconds, send STOP `A5 5A 04 00 00 30 01`. Expect `A5 5A 84 00 01 00 29 44` and no newly produced sample frames. An already queued frame may finish transmitting.
3. Copy one complete `A5 5A 90 ...` frame and, from the project root in PowerShell, run `py -3 .\host\protocol_crc16.py decode "complete Hex frame"`. The script independently checks the CRC and lists all 16 raw codes and converted die temperatures. `py -3 .\host\protocol_crc16.py start` and `stop` can generate the control commands.

PING `A5 5A 01 00 00 20 00` and single temperature read `A5 5A 02 00 00 D0 00` remain available. Command handling has one pending-response slot; send control commands one at a time and wait for replies during tests.

## Continuous data frame

The existing v2 format is `A5 5A TYPE SEQ LEN PAYLOAD CRC_LO CRC_HI`. For `TYPE=90`, `LEN=22` in Hex (34 decimal bytes). `SEQ` increments once per frame and wraps from FF to 00. The first two payload bytes contain the big-endian cumulative drop count; the next 32 bytes contain 16 big-endian, two-byte XADC temperature codes, each with its upper four bits zero. CRC-16/MODBUS starts at FFFF, covers `TYPE` through the final payload byte, excludes `A5 5A`, and is sent low byte first. At nominal rate the output is about 62.5 frames/s or 2,563 UART data bytes/s, below the 11,520-byte/s capacity of 115200 8N1.

Simulation uses fixed temperature code `0977`. Its example frame has `SEQ=00`, zero drops, 16 values of `09 77`, and final CRC bytes `61 4F`. **Actual board readings and CRCs normally differ**; use the host decoder for those frames. `TYPE=83` acknowledges START with data byte `01`; `TYPE=84` acknowledges STOP with data byte `00`.

## Validation

`sim/tb_top_stream.v` in Icarus Verilog covers bad-CRC rejection, START acknowledgment, two 16-sample batches, sequence and CRC, STOP acknowledgment, and stream termination. `sim/tb_sample_fifo.v` covers the 64-entry FIFO's full protection, ordering, pointer wrap, and reset. Vivado 2018.3 completed synthesis, place-and-route, and bitstream generation with 14.275 ns WNS against the 50 MHz constraint. September board checks covered continuous frames, frame CRC and drop fields, STOP, PING, and single temperature read. A later 100-second v6 stream run is in the [board test record](VALIDATION_2026-09-17.md).
