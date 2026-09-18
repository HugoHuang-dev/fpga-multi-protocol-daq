# v8 on-board ILA debug record

ILA samples internal control signals with the board's 50 MHz clock and returns them over JTAG to Vivado Hardware Manager. The debug bitstream and probe map are `releases/xadc_rtc_v8_ila.bit` and `releases/xadc_rtc_v8_ila.ltx`. Seven probe groups were inserted into the synthesized netlist; the functional RTL matches v8. The debug implementation's worst setup slack is 13.248 ns.

## Probe configuration

| Probe | Width | Signal | Observation |
| --- | ---: | --- | --- |
| `probe0` | 1 | `request_valid` | Command-valid pulse after CRC check |
| `probe1` | 8 | `request_type` | PING `01`, START `03`, STOP `04`, RTC read `07` |
| `probe2` | 1 | `streaming` | Continuous-acquisition state |
| `probe3` | 1 | `rtc_reply_valid` | Reply-valid pulse after the RTC transaction |
| `probe4` | 2 | `send_state` | UART reply state machine |
| `probe5` | 8 | `rx_data` | Most recently received UART byte |
| `probe6` | 1 | `rx_valid` | UART byte-received pulse |

`probe1` and `probe4` may appear under synthesized-net names in the waveform viewer; use the probe numbers to identify them. Set eight-bit buses to Hex. The capture depth is 8,192 clock cycles, or about 164 μs. Command reception and RTC replies are armed separately.

## Capture procedure

1. In Vivado 2018.3 Hardware Manager, connect to the Artix-7. Under Program Device, select the `.bit` file above and its matching `.ltx` file.
2. Open `hw_ila_1` Waveform and Trigger Setup. For PING, START, and STOP, use one condition: `request_valid == 1`. Click Run Trigger and confirm **Waiting For Trigger**.
3. Set the serial utility to 115200, 8N1, Hex. Send PING `A5 5A 01 00 00 20 00`, START `A5 5A 03 00 00 81 C0`, and STOP `A5 5A 04 00 00 30 01` in sequence. Rearm before each command; begin START/STOP captures from stopped/running states, respectively.
4. For RTC-read completion, use the single condition `rtc_reply_valid == 1` instead. Rearm and send `A5 5A 07 00 00 C0 01`. Observe `send_state` entering the RTC-reply branch, then check the UART frame with the host decoder.

During integration, a simultaneous `request_valid == 1` and `request_type == 00` trigger kept waiting for START/STOP because their command types did not match 00. With a single-condition trigger, command type and state transitions are visible in the same capture. Vivado continues displaying the previous waveform while waiting for a new trigger; distinguish captures by ILA status and the waveform update time.

## 2026-09-18 board results

| Transaction | ILA observation | UART result |
| --- | --- | --- |
| PING | `request_type=01`, `streaming=0`, then `send_state: 0→1` | `A5 5A 81 00 01 03 69 89`, valid CRC |
| START | `request_type=03`, `streaming: 0→1` | `TYPE=91` sample batches after START acknowledgment |
| STOP | `request_type=04`, `streaming: 1→0` | STOP acknowledged; sample frames ceased |
| RTC read | `rtc_reply_valid=1`, `send_state: 0→3` | `TYPE=87`, eight-byte payload, valid CRC |

The raw RTC UART frame was `A5 5A 87 00 08 6C 42 30 55 58 44 49 26 5A 28`. The host decoded `2026-09-18 15:30:42` and `voltage_low=False`, with CRC `285A`. This ILA capture covers the RTC controller's completed reply path; RTC time read/set and periodic markers are also checked in the [v8 board capture](VALIDATION_V8_2026-09-17.md).

Waveform and decoding screenshots: [PING](evidence/ila/ping.png), [START](evidence/ila/start.png), [STOP](evidence/ila/stop.png), [RTC reply](evidence/ila/rtc_read.png), and [RTC decode](evidence/ila/rtc_decode.png).
