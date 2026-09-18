# MATLAB host five-second live board capture

`project1_host("live", "COM10", Duration=5, ...)` ran at 115200 8N1 and wrote `matlab/matlab_live_5s/`. The MATLAB `summary.json` matched an independent Python monitor replay of `capture.bin`:

- Actual capture duration: 5.010 seconds; 12,924 bytes received.
- 313 four-channel `TYPE=91` batch frames containing 5,008 records; 1,252 each for temperature, VCCINT, VCCAUX, and VCCBRAM.
- Five `TYPE=92` RTC markers, spanning board-local time 2026-09-17 21:39:25 to 21:39:29.
- Both START and STOP acknowledged. CRC errors, invalid lengths, sample sequence gaps, FPGA-reported FIFO drops, invalid samples, and invalid RTC markers were all zero.
- Die temperature range 32.852–35.559 °C; VCCINT 1.002–1.009 V; VCCAUX 1.798–1.808 V; VCCBRAM 1.002–1.009 V. Precise converted values remain in the JSON/CSV files.

This short run covered MATLAB live serial acquisition, CRC checking, four-channel decoding, RTC markers, and data export. See the [MATLAB host guide](MATLAB_HOST.md) for offline replay and corrupted-frame injection tests.
