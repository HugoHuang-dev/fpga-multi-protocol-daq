# Project 1 UART protocol v2 (CRC-16)

Frame: `A5 5A | TYPE | SEQ | LEN | PAYLOAD[LEN] | CRC_LO | CRC_HI`. `TYPE` identifies the command or response; the PC supplies `SEQ`, which the response echoes; `LEN` is the payload length in bytes. The CRC covers **only `TYPE | SEQ | LEN | PAYLOAD`**—neither the `A5 5A` header nor the CRC bytes themselves.

`crc16_d8.v` updates CRC-16/MODBUS byte by byte, using initial value `0xFFFF`, reflected polynomial `0xA001`, and no final XOR. The standard `123456789` test vector yields `0x4B37`. The low CRC byte is transmitted first. The header, type, and payload layout are defined by this project protocol; the CRC byte order matches the [Modbus serial specification](https://www.modbus.org/file/secure/modbusoverserial.pdf).

v2 commands (request `LEN=00` for both):

| TYPE | Purpose | Response |
| --- | --- | --- |
| `01` | PING | `81` with one-byte protocol version `02` |
| `02` | Read raw on-chip XADC temperature | `82` with two raw bytes, high byte first; if the sensor is not ready, `E0` with error code `01` |

A request with an invalid CRC is discarded without a reply. v2 defines the two zero-payload commands above. UART is fixed at 115200, 8N1, no flow control, with a 128-byte TX FIFO. The four-frame sequence below checks the order of replies to consecutive commands.

**Bad-CRC test:** Send `A5 5A 01 00 00 21 00`, with the low CRC byte changed from the correct `20` to `21`. The receiver discards it and produces no response. Then send the valid `A5 5A 01 00 00 20 00` and expect a PING response.

Hex frames for a serial utility:

| Operation | Send | Expected response |
| --- | --- | --- |
| PING, sequence `00` | `A5 5A 01 00 00 20 00` | `A5 5A 81 00 01 02 A8 49` |
| Read temperature, sequence `00` | `A5 5A 02 00 00 D0 00` | `A5 5A 82 00 02 HH LL CRC_LO CRC_HI` |

For four consecutive requests, paste this entire line as one Hex stream:

`A5 5A 01 10 00 2D C0 A5 5A 01 11 00 2C 50 A5 5A 01 12 00 2C A0 A5 5A 01 13 00 2D 30`

The replies should arrive in this order:

`A5 5A 81 10 01 02 A9 8C A5 5A 81 11 01 02 F8 4C A5 5A 81 12 01 02 08 4C A5 5A 81 13 01 02 59 8C`

For a temperature reply `HH LL`, the raw value is `0xHHLL` and die temperature is approximately `raw × 503.975 / 4096 − 273.15` °C. `host/protocol_crc16.py` generates Hex commands, verifies response CRCs, and converts temperatures without opening the serial port. Run these from the project root:

```text
py -3 .\host\protocol_crc16.py ping
py -3 .\host\protocol_crc16.py temp
py -3 .\host\protocol_crc16.py decode "A5 5A 81 00 01 02 A8 49"
```

The v2 bitstream uses CRC-16 framing. The v1 CRC-8 command format remains in the separate v1 project.
