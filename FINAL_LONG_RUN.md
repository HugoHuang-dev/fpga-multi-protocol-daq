# v8 two-hour continuous run

The final run on 2026-09-18 used `releases/xadc_rtc_v8.bit` and [`stream_monitor.py`](host/stream_monitor.py). The monitor sent START, saved the raw UART stream, and counted protocol errors, four-channel records, and RTC markers. After 7,200 seconds it sent STOP and received an acknowledgment. The measured results are in the [two-hour validation record](VALIDATION_FINAL_2026-09-18.md).

## Run command

To reproduce the configuration, run the following from the project root. `COM11` was the port for this run; the monitor has exclusive access while running.

```powershell
py -3 .\host\stream_monitor.py --port COM11 --duration 7200 --raw .\capture_v8_final_2h.bin --summary .\capture_v8_final_2h.json > .\capture_v8_final_2h.log
```

Before the run, read the RTC with `A5 5A 07 00 00 C0 01`. If it needs setting, generate a set-time frame, wait for the `TYPE=88` acknowledgment, and read it back:

```powershell
$rtcNow = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
py -3 .\host\protocol_crc16.py rtc-set --time $rtcNow
```

The monitor writes the raw `.bin` stream, a `.json` statistical summary, and a `.log` terminal record. Replay the raw data to recheck frame counts, channel records, time markers, and error counts:

```powershell
py -3 .\host\stream_monitor.py --input .\capture_v8_final_2h.bin --summary .\capture_v8_final_2h_replay.json
```

## Checks

| Area | Check |
| --- | --- |
| Completion | `duration_seconds` about 7,200; both START and STOP acknowledged |
| Samples | Continuous `TYPE=91` frames; equal counts in all four `records_by_channel` entries |
| RTC | Periodic `TYPE=92` markers; monotonically increasing time; `voltage_low=false` |
| UART/protocol | `crc_errors`, `invalid_lengths`, `discarded_bytes_during_resync`, and `missing_sample_frames_by_sequence` all zero |
| FIFO/records | `reported_drop_count_increase`, `invalid_sample_records`, `invalid_rtc_time_markers`, and `incomplete_bytes_at_end` all zero |

The measured run lasted **7200.009 seconds** and produced **449,989 sample frames, 7,199,824 records, and 7,199 RTC markers**. Every error count in the table was zero. Offline replay does not measure elapsed wall time, so `duration_seconds` and `sample_frames_per_second` are null in its summary.

See the [final validation record](VALIDATION_FINAL_2026-09-18.md) for the two-hour data, raw capture, and hash. The earlier [five-second v8 capture](VALIDATION_V8_2026-09-17.md) is retained separately.
