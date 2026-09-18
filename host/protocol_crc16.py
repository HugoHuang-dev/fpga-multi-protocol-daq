"""Project 1 protocol v2 frame builder/inspector. Python standard library only.

CRC-16/MODBUS is used for our custom frame; the frame itself is not Modbus.
"""

import argparse
from datetime import datetime


MAGIC = b"\xA5\x5A"


def crc16_modbus(data: bytes) -> int:
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0xA001 if crc & 1 else 0)
    return crc


def make_frame(kind: int, seq: int = 0, payload: bytes = b"") -> bytes:
    if not 0 <= kind <= 255 or not 0 <= seq <= 255 or len(payload) > 255:
        raise ValueError("type, sequence, or payload length out of range")
    body = bytes((kind, seq, len(payload))) + payload
    return MAGIC + body + crc16_modbus(body).to_bytes(2, "little")


def decode_stream(data: bytes) -> list[dict]:
    frames = []
    pos = 0
    while pos < len(data):
        if data[pos : pos + 2] != MAGIC:
            raise ValueError(f"expected A5 5A at byte offset {pos}")
        if len(data) - pos < 7:
            raise ValueError(f"incomplete header at byte offset {pos}")
        length = data[pos + 4]
        end = pos + 7 + length
        if end > len(data):
            raise ValueError(f"incomplete payload at byte offset {pos}")
        body = data[pos + 2 : end - 2]
        received_crc = int.from_bytes(data[end - 2 : end], "little")
        expected_crc = crc16_modbus(body)
        if received_crc != expected_crc:
            raise ValueError(
                f"CRC error at offset {pos}: received {received_crc:04X}, "
                f"expected {expected_crc:04X}"
            )
        frame = {
            "type": body[0],
            "seq": body[1],
            "payload": body[3:],
            "crc": received_crc,
        }
        frames.append(frame)
        pos = end
    return frames


def hex_bytes(data: bytes) -> str:
    return data.hex(" ").upper()


def to_bcd(value: int) -> int:
    return (value // 10 << 4) | value % 10


def from_bcd(value: int) -> int:
    if value & 0x0F > 9 or value >> 4 > 9:
        raise ValueError(f"invalid BCD byte {value:02X}")
    return (value >> 4) * 10 + (value & 0x0F)


def rtc_set_payload(when: datetime) -> bytes:
    if when.tzinfo is not None:
        raise ValueError("RTC stores local wall time; omit a timezone offset")
    if not 2000 <= when.year <= 2099:
        raise ValueError("RTC command supports years 2000..2099")
    return bytes(to_bcd(value) for value in (
        when.second, when.minute, when.hour, when.day,
        when.weekday(), when.month, when.year - 2000,
    ))


def decode_rtc_payload(payload: bytes) -> dict:
    if len(payload) != 8:
        raise ValueError("RTC payload must contain a batch anchor and seven registers")
    anchor, seconds, minutes, hours, day, weekday, month, year = payload
    low_voltage = bool(seconds & 0x80)
    values = tuple(from_bcd(value) for value in (
        seconds & 0x7F, minutes & 0x7F, hours & 0x3F,
        day & 0x3F, weekday & 0x07, month & 0x1F, year,
    ))
    sec, minute, hour, date, dow, mon, yr = values
    if dow > 6:
        raise ValueError("invalid RTC weekday")
    when = datetime(2000 + yr, mon, date, hour, minute, sec)
    return {"next_batch_seq": anchor, "time": when.isoformat(sep=" "),
            "voltage_low": low_voltage, "century_bit": bool(month & 0x80)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("ping", "temp", "start", "stop", "rtc-read"):
        cmd = sub.add_parser(name, help=f"print a {name} request as Hex")
        cmd.add_argument("--seq", type=lambda x: int(x, 0), default=0)
    for name in ("eeprom-read", "eeprom-write"):
        cmd = sub.add_parser(name, help=f"print an {name} request as Hex")
        cmd.add_argument("--addr", type=lambda x: int(x, 0), required=True)
        cmd.add_argument("--seq", type=lambda x: int(x, 0), default=0)
        if name == "eeprom-write":
            cmd.add_argument("--value", type=lambda x: int(x, 0), required=True)
    inspect = sub.add_parser("decode", help="check one or more received frames")
    inspect.add_argument("hex", help='e.g. "A5 5A 81 00 01 02 A8 49"')
    rtc_set = sub.add_parser("rtc-set", help="print a PCF8563 time-setting request")
    rtc_set.add_argument("--time", required=True, help="local time YYYY-MM-DDTHH:MM:SS")
    rtc_set.add_argument("--seq", type=lambda x: int(x, 0), default=0)
    args = parser.parse_args()

    if args.command in ("ping", "temp", "start", "stop", "rtc-read"):
        kind = {"ping": 1, "temp": 2, "start": 3, "stop": 4,
                "rtc-read": 7}[args.command]
        print(hex_bytes(make_frame(kind, args.seq)))
        return
    if args.command == "rtc-set":
        try:
            payload = rtc_set_payload(datetime.fromisoformat(args.time))
        except ValueError as exc:
            parser.error(str(exc))
        print(hex_bytes(make_frame(8, args.seq, payload)))
        return
    if args.command in ("eeprom-read", "eeprom-write"):
        if not 0 <= args.addr <= 0x1FFF:
            parser.error("24C64 address must be 0x0000..0x1FFF")
        payload = args.addr.to_bytes(2, "big")
        if args.command == "eeprom-write":
            if not 0 <= args.value <= 255:
                parser.error("EEPROM value must be 0x00..0xFF")
            payload += bytes((args.value,))
        kind = 5 if args.command == "eeprom-read" else 6
        print(hex_bytes(make_frame(kind, args.seq, payload)))
        return

    for frame in decode_stream(bytes.fromhex(args.hex)):
        payload = frame["payload"]
        print(
            f"type={frame['type']:02X} seq={frame['seq']:02X} "
            f"payload={hex_bytes(payload)} CRC={frame['crc']:04X} OK"
        )
        if frame["type"] == 0x82 and len(payload) == 2:
            raw = int.from_bytes(payload, "big")
            temp_c = raw * 503.975 / 4096 - 273.15
            print(f"XADC raw=0x{raw:03X}, chip temperature={temp_c:.2f} C")
        if frame["type"] == 0x90 and len(payload) == 34:
            drops = int.from_bytes(payload[:2], "big")
            samples = [int.from_bytes(payload[i : i + 2], "big")
                       for i in range(2, 34, 2)]
            temps = [raw * 503.975 / 4096 - 273.15 for raw in samples]
            print(f"sample batch: 16 values, cumulative drops={drops}")
            print("raw=" + " ".join(f"{raw:03X}" for raw in samples))
            print("chip temperature C=" + " ".join(f"{t:.2f}" for t in temps))
        if frame["type"] == 0x91 and len(payload) == 34:
            drops = int.from_bytes(payload[:2], "big")
            names = ("temperature", "VCCINT", "VCCAUX", "VCCBRAM")
            print(f"multi-channel batch: 16 records, cumulative drops={drops}")
            for i in range(2, 34, 2):
                word = int.from_bytes(payload[i : i + 2], "big")
                channel, raw = word >> 14, word & 0xFFF
                if word & 0x3000:
                    raise ValueError(f"reserved sample bits are set in {word:04X}")
                value = raw * 503.975 / 4096 - 273.15 if channel == 0 else raw * 3 / 4096
                unit = "C" if channel == 0 else "V"
                print(f"  {names[channel]:11s} raw=0x{raw:03X} value={value:.3f} {unit}")
        if frame["type"] == 0x85 and len(payload) == 1:
            print(f"EEPROM read byte=0x{payload[0]:02X}")
        if frame["type"] == 0x86 and payload == b"\x00":
            print("EEPROM write transaction ACKed; read back to verify contents")
        if frame["type"] == 0xE1:
            print("EEPROM I2C NACK: check bus/device or wait for write cycle")
        if frame["type"] == 0xE2:
            print("EEPROM request busy: retry after prior request finishes")
        if frame["type"] in (0x87, 0x92) and len(payload) == 8:
            try:
                rtc = decode_rtc_payload(payload)
                print(f"RTC time={rtc['time']} next_batch_seq={rtc['next_batch_seq']:02X} "
                      f"voltage_low={rtc['voltage_low']}")
            except ValueError as exc:
                print(f"RTC data invalid: {exc}; raw={hex_bytes(payload)}")
        if frame["type"] == 0x88 and payload == b"\x00":
            print("RTC set transaction ACKed; read back to verify the clock")
        if frame["type"] == 0xE3:
            print("RTC I2C NACK: check the PCF8563 or shared bus")
        if frame["type"] == 0xE4:
            print("RTC request busy: retry after the current I2C transaction")


if __name__ == "__main__":
    main()
