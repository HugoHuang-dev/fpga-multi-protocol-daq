function test_project1_host(projectRoot)
%TEST_PROJECT1_HOST Check MATLAB decoding against the board capture and Python report.
% Run directly from any MATLAB working folder: test_project1_host
if nargin == 0 || strlength(string(projectRoot)) == 0
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end
projectRoot = string(projectRoot);
addpath(fullfile(projectRoot,'matlab'));
assert(isequal(project1_frame(uint8(3)),uint8([165 90 3 0 0 129 192])));
assert(isequal(project1_frame(uint8(4)),uint8([165 90 4 0 0 48 1])));
expected = jsondecode(fileread(fullfile(projectRoot,'capture_v8.json')));
outputDir = string(tempname);
[report,samples] = project1_host("replay", fullfile(projectRoot,'fixtures','v8_short_uart.bin'), ...
    Plot=false, OutputDir=outputDir);
assert(report.bytes_received == expected.bytes_received);
assert(report.sample_frames == expected.sample_frames);
assert(report.samples_received == expected.samples_received);
assert(report.valid_frames_by_type.type_83 == 1);
assert(report.valid_frames_by_type.type_91 == 312);
assert(report.valid_frames_by_type.type_92 == 5);
assert(report.valid_frames_by_type.type_84 == 1);
assert(report.records_by_channel.temperature == 1248);
assert(report.records_by_channel.VCCINT == 1248);
assert(report.records_by_channel.VCCAUX == 1248);
assert(report.records_by_channel.VCCBRAM == 1248);
assert(abs(report.channel_ranges.temperature.minimum-32.729)<0.001);
assert(abs(report.channel_ranges.temperature.maximum-35.313)<0.001);
assert(abs(report.channel_ranges.VCCINT.minimum-1.002)<0.001);
assert(abs(report.channel_ranges.VCCAUX.maximum-1.808)<0.001);
assert(report.crc_errors==0 && report.invalid_lengths==0);
assert(report.missing_sample_frames_by_sequence==0);
assert(report.reported_drop_count_increase==0);
assert(report.invalid_sample_records==0 && report.invalid_rtc_time_markers==0);
assert(report.start_ack_received && report.stop_ack_received);
assert(numel(report.rtc_time_markers)==5);
assert(strcmp(report.rtc_time_markers(1).time,'2026-09-17 20:09:18'));
assert(strcmp(report.rtc_time_markers(5).time,'2026-09-17 20:09:22'));
assert(height(samples)==4992);
assert(isfile(fullfile(outputDir,'samples.csv')));
assert(isfile(fullfile(outputDir,'rtc_markers.csv')));
assert(isfile(fullfile(outputDir,'summary.json')));
fid = fopen(fullfile(projectRoot,'fixtures','v8_short_uart.bin'),'rb');
bytes = fread(fid,Inf,'*uint8');
fclose(fid);
bytes(100) = bitxor(bytes(100),uint8(1));
corruptFile = fullfile(outputDir,'corrupt.bin');
fid = fopen(corruptFile,'wb');
fwrite(fid,bytes,'uint8');
fclose(fid);
bad = project1_host("replay",corruptFile,Plot=false);
assert(bad.crc_errors>=1);
assert(bad.sample_frames==311);
assert(bad.missing_sample_frames_by_sequence==1);
oldVisibility = get(groot,'DefaultFigureVisible');
visibilityCleaner = onCleanup(@() set(groot,'DefaultFigureVisible',oldVisibility));
existingFigures = findall(groot,'Type','figure');
set(groot,'DefaultFigureVisible','off');
project1_host("replay", fullfile(projectRoot,'fixtures','v8_short_uart.bin'),Plot=true);
newFigures = setdiff(findall(groot,'Type','figure'),existingFigures);
delete(newFigures);
clear visibilityCleaner
disp('MATLAB v8 replay, CRC, four channels, RTC, and export: PASS');
end
