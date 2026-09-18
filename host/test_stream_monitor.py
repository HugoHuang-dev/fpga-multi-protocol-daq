"""Checks for capture parsing across serial read boundaries and damaged frames."""

import unittest

from datetime import datetime

from protocol_crc16 import decode_rtc_payload, make_frame, rtc_set_payload
from stream_monitor import FrameMonitor


def batch(seq, drops, raw=0x9C1):
    payload = drops.to_bytes(2, "big") + raw.to_bytes(2, "big") * 16
    return make_frame(0x90, seq, payload)


class FrameMonitorTest(unittest.TestCase):
    def test_rtc_set_encoding_and_time_marker(self):
        when = datetime(2026, 9, 17, 19, 25, 34)
        self.assertEqual(rtc_set_payload(when), bytes.fromhex("34 25 19 17 03 09 26"))
        monitor = FrameMonitor()
        marker = bytes.fromhex("04 34 25 19 17 03 09 26")
        monitor.feed(make_frame(0x92, 4, marker))
        result = monitor.summary(1.0)
        self.assertEqual(result["rtc_time_markers"][0]["time"],
                         "2026-09-17 19:25:34")
        self.assertEqual(result["rtc_time_markers"][0]["next_batch_seq"], 4)
        self.assertFalse(decode_rtc_payload(marker)["voltage_low"])
        monitor.feed(make_frame(0x92, 5, bytes.fromhex("05 B4 25 19 17 03 09 26")))
        self.assertTrue(monitor.summary(1.0)["rtc_time_markers"][1]["voltage_low"])

    def test_four_channel_batch_decoding(self):
        monitor = FrameMonitor()
        records = (0x0977, 0x4555, 0x8999, 0xC556) * 4
        payload = b"\x00\x00" + b"".join(word.to_bytes(2, "big") for word in records)
        monitor.feed(make_frame(0x91, 0, payload))
        result = monitor.summary(1.0)
        self.assertEqual(result["records_by_channel"], {
            "temperature": 4, "VCCINT": 4, "VCCAUX": 4, "VCCBRAM": 4
        })
        self.assertEqual(result["channel_ranges"]["VCCINT"]["minimum"],
                         round(0x555 * 3 / 4096, 3))
        self.assertEqual(result["invalid_sample_records"], 0)

    def test_chunks_sequence_wrap_and_drop_counter(self):
        monitor = FrameMonitor()
        data = make_frame(0x83, 0, b"\x01") + batch(0xFE, 0xFFFE)
        data += batch(0xFF, 0xFFFF) + batch(0x00, 0x0001)
        data += make_frame(0x84, 0, b"\x00")
        for i in range(0, len(data), 3):
            monitor.feed(data[i : i + 3])
        result = monitor.summary(1.0)
        self.assertEqual(result["sample_frames"], 3)
        self.assertEqual(result["samples_received"], 48)
        self.assertEqual(result["missing_sample_frames_by_sequence"], 0)
        self.assertEqual(result["reported_drop_count_increase"], 3)
        self.assertEqual(result["crc_errors"], 0)
        self.assertTrue(result["start_ack_received"])
        self.assertTrue(result["stop_ack_received"])

    def test_corrupt_frame_resynchronizes_and_reports_gap(self):
        monitor = FrameMonitor()
        damaged = bytearray(batch(5, 0))
        damaged[8] ^= 0x01
        monitor.feed(b"noise\xA5" + batch(4, 0) + damaged + batch(6, 0))
        result = monitor.summary(1.0)
        self.assertEqual(result["sample_frames"], 2)
        self.assertEqual(result["crc_errors"], 1)
        self.assertEqual(result["missing_sample_frames_by_sequence"], 1)
        self.assertGreater(result["discarded_bytes_during_resync"], 0)


if __name__ == "__main__":
    unittest.main()
