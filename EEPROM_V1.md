# v6: On-board I²C EEPROM single-byte read/write

v6 adds the on-board 24C64 EEPROM to v5's continuous temperature acquisition, two FIFOs, CRC-16, and UART protocol. The schematic's `DEVICE` sheet identifies U5 as a 24C64. A0/A1/A2 and WP are grounded; SCL/SDA have 4.7 kΩ pull-ups to 3.3 V and share the IIC1 bus with the RTC. The board XDC maps `iic_scl` to R6 and `iic_sda` to T4. The I²C controller drives both lines open-drain at approximately 100 kHz. The seven-bit device address is `0x50`; storage addresses span `0x0000..0x1FFF` and are transmitted high byte first. `eeprom_iic_master.v` sequences START, address, ACK, data, and STOP for single-byte transactions and waits 10 ms after a write before replying. A CRC-checked UART command starts each transaction; a NACK has a separate error response.

## Board test

Run `create_eeprom_project.tcl` and `build_eeprom_bitstream.tcl` in Vivado 2018.3, then open the generated project and program its bitstream. Use **115200, 8N1, Hex** on the serial port. First send the existing PING `A5 5A 01 00 00 20 00` and expect `A5 5A 81 00 01 02 A8 49`. Stop the continuous stream before EEPROM tests so each response is easy to identify.

The sequence below uses address `0x1FF0`. **Neither the device nor the board guarantees that this address is unused.** Read and record its original value, then restore it after the test.

1. Read the original value: send `A5 5A 05 00 02 1F F0 41 B4`. The response has the form `A5 5A 85 00 01 XX CRC_LO CRC_HI`; `XX` is the stored byte. Verify the full frame with `py -3 .\host\protocol_crc16.py decode "full frame in Hex"`.
2. Write test value A6: send `A5 5A 06 01 03 1F F0 A6 C8 45`. After approximately 10 ms, expect `A5 5A 86 01 01 00 79 3C`. Follow it with a random read.
3. Read back: send `A5 5A 05 02 02 1F F0 40 0C`. Expect `A5 5A 85 02 01 A6 09 02`.
4. Restore the original byte: run `py -3 .\host\protocol_crc16.py eeprom-write --addr 0x1FF0 --value 0xXX --seq 3`, replacing `XX` with the byte from step 1. Send the generated Hex command, then read back once more.

Generate commands for other addresses or values with `py -3 .\host\protocol_crc16.py eeprom-read --addr 0x1FF0 --seq 0` or `py -3 .\host\protocol_crc16.py eeprom-write --addr 0x1FF0 --value 0xA6 --seq 1`. Wait for each reply before sending the next command. A device NACK returns `TYPE=E1, PAYLOAD=01`; an EEPROM command while the previous one is active returns `TYPE=E2, PAYLOAD=01`. Bad CRC or an out-of-range address starts no EEPROM transaction and receives no reply. CRC-16 still covers `TYPE` through `PAYLOAD` and is sent low byte first.

## Validation

`tb_eeprom_iic_master.v` models a write, repeated-START random read, ACK, and open-drain timing. `tb_top_eeprom.v` verifies the UART/CRC command → I²C → UART/CRC response path, device NACK, and PING. `tb_top_eeprom_stream.v` verifies that continuous temperature streaming still runs under the new top level. Vivado 2018.3 generated a bitstream and met the 50 MHz timing constraint (WNS 14.074 ns). On the board, address `0x1FF0` initially held `FF`; after writing `A6`, the readback was `A6`, with valid reply CRCs.

When restoring the original value, the board returned write acknowledgment `A5 5A 86 03 01 00 D8 FC` and readback `A5 5A 85 04 01 FF 29 39`. Address `0x1FF0` was restored to `FF`.

The transaction format and write cycle follow the [Microchip 24AA64/24LC64/24FC64 datasheet](https://ww1.microchip.com/downloads/aemDocuments/documents/MPD/ProductDocuments/DataSheets/24AA64-24FC64-24LC64-64-Kbit-I2C-Serial-EEPROM-DS20001189.pdf). The board marks the device generically as `24C64`; the fixed post-write delay is 10 ms.
