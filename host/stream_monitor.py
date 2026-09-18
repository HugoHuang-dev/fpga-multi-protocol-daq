"""Capture and check Project 1 UART sample streams, including v8 RTC markers.

Offline replay uses only the standard library. Live serial capture needs pyserial.
"""

import argparse
import json
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from protocol_crc16 import MAGIC, crc16_modbus, decode_rtc_payload, make_frame


MAX_PAYLOAD = 64  # v6's largest defined payload is a 34-byte sample batch.


class FrameMonitor:
    def __init__(self):
        self.buffer = bytearray()
        self.bytes_received = 0
        self.discarded_bytes = 0
        self.crc_errors = 0
        self.invalid_lengths = 0
        self.types = Counter()
        self.sample_frames = 0
        self.samples = 0
        self.sequence_gaps = 0
        self.previous_seq = None
        self.first_drops = None
        self.last_drops = None
        self.reported_drop_increase = 0
        self.minimum_raw = None
        self.maximum_raw = None
        self.channel_counts = Counter()
        self.channel_minimum_raw = {}
        self.channel_maximum_raw = {}
        self.invalid_records = 0
        self.start_ack = False
        self.stop_ack = False
        self.rtc_markers = []
        self.invalid_rtc_markers = 0

    def feed(self, chunk):
        self.bytes_received += len(chunk)
        self.buffer.extend(chunk)
        while self.buffer:
            marker = self.buffer.find(MAGIC)
            if marker < 0:
                # Keep a trailing A5: the next read may begin with 5A.
                keep = 1 if self.buffer[-1] == MAGIC[0] else 0
                self.discarded_bytes += len(self.buffer) - keep
                del self.buffer[: len(self.buffer) - keep]
                return
            if marker:
                self.discarded_bytes += marker
                del self.buffer[:marker]
            if len(self.buffer) < 5:
                return
            length = self.buffer[4]
            if length > MAX_PAYLOAD:
                self.invalid_lengths += 1
                self.discarded_bytes += 1
                del self.buffer[0]
                continue
            frame_length = 7 + length
            if len(self.buffer) < frame_length:
                return
            body = self.buffer[2 : frame_length - 2]
            received_crc = int.from_bytes(self.buffer[frame_length - 2 : frame_length], "little")
            if received_crc != crc16_modbus(body):
                self.crc_errors += 1
                self.discarded_bytes += 1
                del self.buffer[0]
                continue
            kind, seq = body[:2]
            payload = bytes(body[3:])
            self.types[f"{kind:02X}"] += 1
            if kind == 0x83 and payload == b"\x01":
                self.start_ack = True
            elif kind == 0x84 and payload == b"\x00":
                self.stop_ack = True
            elif kind in (0x90, 0x91) and length == 34:
                self._sample_batch(kind, seq, payload)
            elif kind == 0x92 and length == 8:
                try:
                    marker = decode_rtc_payload(payload)
                    marker["frame_seq"] = seq
                    marker["sample_frames_seen"] = self.sample_frames
                    self.rtc_markers.append(marker)
                except ValueError:
                    self.invalid_rtc_markers += 1
            del self.buffer[:frame_length]

    def _sample_batch(self, kind, seq, payload):
        self.sample_frames += 1
        self.samples += 16
        if self.previous_seq is not None:
            self.sequence_gaps += (seq - self.previous_seq - 1) & 0xFF
        self.previous_seq = seq
        drops = int.from_bytes(payload[:2], "big")
        if self.first_drops is None:
            self.first_drops = drops
        if self.last_drops is not None:
            self.reported_drop_increase += (drops - self.last_drops) & 0xFFFF
        self.last_drops = drops
        for i in range(2, 34, 2):
            word = int.from_bytes(payload[i : i + 2], "big")
            if kind == 0x91 and word & 0x3000:
                self.invalid_records += 1
            channel = word >> 14 if kind == 0x91 else 0
            raw = word & 0xFFF
            self.channel_counts[channel] += 1
            if channel == 0:
                self.minimum_raw = raw if self.minimum_raw is None else min(self.minimum_raw, raw)
                self.maximum_raw = raw if self.maximum_raw is None else max(self.maximum_raw, raw)
            self.channel_minimum_raw[channel] = min(self.channel_minimum_raw.get(channel, raw), raw)
            self.channel_maximum_raw[channel] = max(self.channel_maximum_raw.get(channel, raw), raw)

    def summary(self, duration_seconds):
        return {
            "duration_seconds": round(duration_seconds, 3),
            "bytes_received": self.bytes_received,
            "valid_frames_by_type": dict(self.types),
            "sample_frames": self.sample_frames,
            "samples_received": self.samples,
            "records_by_channel": {
                ("temperature", "VCCINT", "VCCAUX", "VCCBRAM")[channel]: count
                for channel, count in sorted(self.channel_counts.items())
            },
            "channel_ranges": {
                ("temperature", "VCCINT", "VCCAUX", "VCCBRAM")[channel]: {
                    "minimum": round(self.channel_minimum_raw[channel] *
                                     (503.975 if channel == 0 else 3) / 4096 -
                                     (273.15 if channel == 0 else 0), 3),
                    "maximum": round(self.channel_maximum_raw[channel] *
                                     (503.975 if channel == 0 else 3) / 4096 -
                                     (273.15 if channel == 0 else 0), 3),
                    "unit": "C" if channel == 0 else "V",
                }
                for channel in sorted(self.channel_counts)
            },
            "invalid_sample_records": self.invalid_records,
            "rtc_time_markers": self.rtc_markers,
            "invalid_rtc_time_markers": self.invalid_rtc_markers,
            "sample_frames_per_second": round(self.sample_frames / duration_seconds, 3)
            if duration_seconds else None,
            "crc_errors": self.crc_errors,
            "invalid_lengths": self.invalid_lengths,
            "discarded_bytes_during_resync": self.discarded_bytes,
            "missing_sample_frames_by_sequence": self.sequence_gaps,
            "first_reported_drop_count": self.first_drops,
            "last_reported_drop_count": self.last_drops,
            "reported_drop_count_increase": self.reported_drop_increase,
            "minimum_temperature_c": round(self.minimum_raw * 503.975 / 4096 - 273.15, 2)
            if self.minimum_raw is not None else None,
            "maximum_temperature_c": round(self.maximum_raw * 503.975 / 4096 - 273.15, 2)
            if self.maximum_raw is not None else None,
            "start_ack_received": self.start_ack,
            "stop_ack_received": self.stop_ack,
            "incomplete_bytes_at_end": len(self.buffer),
        }


def capture(port, baud, duration, raw_path, monitor):
    try:
        import serial
    except ImportError as exc:
        raise SystemExit("Live capture requires pyserial: py -3 -m pip install pyserial") from exc
    with serial.Serial(port=port, baudrate=baud, timeout=0.2, rtscts=False, xonxoff=False) as connection:
        with raw_path.open("wb") as raw_file:
            started = time.monotonic()
            recording_duration = 0.0
            connection.write(make_frame(0x03))
            try:
                while time.monotonic() - started < duration:
                    chunk = connection.read(connection.in_waiting or 1)
                    if chunk:
                        raw_file.write(chunk)
                        monitor.feed(chunk)
            finally:
                recording_duration = time.monotonic() - started
                connection.write(make_frame(0x04))
                deadline = time.monotonic() + 2.0
                while time.monotonic() < deadline and not monitor.stop_ack:
                    chunk = connection.read(connection.in_waiting or 1)
                    if chunk:
                        raw_file.write(chunk)
                        monitor.feed(chunk)
        return recording_duration


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--port", help="COM port for live capture, e.g. COM9")
    source.add_argument("--input", type=Path, help="replay a previously saved binary capture")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--duration", type=float, default=60.0, help="live recording time in seconds")
    parser.add_argument("--raw", type=Path, help="output binary capture path for a live run")
    parser.add_argument("--summary", type=Path, help="output JSON summary path")
    args = parser.parse_args()
    if args.port and args.duration <= 0:
        parser.error("--duration must be positive")
    if args.input and args.raw:
        parser.error("--raw applies only to live capture")
    monitor = FrameMonitor()
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    if args.port:
        raw_path = args.raw or Path(f"capture_{timestamp}.bin")
        duration = capture(args.port, args.baud, args.duration, raw_path, monitor)
    else:
        raw_path = args.input
        started = time.monotonic()
        with raw_path.open("rb") as raw_file:
            while chunk := raw_file.read(4096):
                monitor.feed(chunk)
        duration = time.monotonic() - started
    report = monitor.summary(duration)
    report["mode"] = "live" if args.port else "replay"
    report["raw_capture"] = str(raw_path)
    report["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
    if args.input:
        report["duration_seconds"] = None
        report["sample_frames_per_second"] = None
    output = json.dumps(report, ensure_ascii=False, indent=2)
    if args.summary:
        args.summary.write_text(output + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
