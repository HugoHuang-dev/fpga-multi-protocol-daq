function [report, samples] = project1_host(mode, source, opts)
%PROJECT1_HOST Replay or capture the Project 1 v8 UART data stream.
%  [REPORT,SAMPLES] = project1_host("replay", "../fixtures/v8_short_uart.bin", Plot=false)
%  [REPORT,SAMPLES] = project1_host("live", "COM10", Duration=5)
%  Live mode requires the board's v8 bitstream and exclusive access to COM.

arguments
    mode (1,1) string {mustBeMember(mode,["replay","live"])}
    source (1,1) string
    opts.Duration (1,1) double {mustBePositive} = 5
    opts.Baud (1,1) double {mustBePositive} = 115200
    opts.Plot (1,1) logical = true
    opts.OutputDir (1,1) string = ""
end

state = newState();
captureDuration = NaN;
if mode == "replay"
    fid = fopen(source, 'rb');
    if fid < 0, error('Cannot open capture: %s', source); end
    cleaner = onCleanup(@() fclose(fid));
    while true
        chunk = fread(fid, 4096, '*uint8');
        if isempty(chunk), break; end
        state = feed(state, chunk);
    end
    clear cleaner
else
    sp = serialport(source, opts.Baud, 'Timeout', 0.2);
    rawCapacity = 65536;
    raw = zeros(1,rawCapacity,'uint8');
    rawCount = 0;
    flush(sp);
    write(sp, project1_frame(uint8(3)), 'uint8');
    timer = tic;
    nextPlot = 0;
    try
        while toc(timer) < opts.Duration
            available = sp.NumBytesAvailable;
            if available > 0
                chunk = read(sp, available, 'uint8');
                [raw,rawCount] = appendRaw(raw,rawCount,chunk);
                state = feed(state, chunk);
            else
                pause(0.01);
            end
            if opts.Plot && toc(timer) >= nextPlot
                drawChannels(state);
                nextPlot = toc(timer) + 0.25;
            end
        end
        captureDuration = toc(timer);
        write(sp, project1_frame(uint8(4)), 'uint8');
        stopTimer = tic;
        while ~state.stop_ack && toc(stopTimer) < 2
            available = sp.NumBytesAvailable;
            if available > 0
                chunk = read(sp, available, 'uint8');
                [raw,rawCount] = appendRaw(raw,rawCount,chunk);
                state = feed(state, chunk);
            else
                pause(0.01);
            end
        end
    catch err
        try, write(sp, project1_frame(uint8(4)), 'uint8'); catch, end
        rethrow(err)
    end
    raw = raw(1:rawCount);
    clear sp
end

samples = sampleTable(state);
report = makeReport(state, captureDuration, mode, source);
if opts.Plot, drawChannels(state); end
if opts.OutputDir ~= ""
    if ~isfolder(opts.OutputDir), mkdir(opts.OutputDir); end
    writetable(samples, fullfile(opts.OutputDir, 'samples.csv'));
    rtc = rtcTable(state);
    writetable(rtc, fullfile(opts.OutputDir, 'rtc_markers.csv'));
    jsonPath = fullfile(opts.OutputDir, 'summary.json');
    fid = fopen(jsonPath, 'w');
    if fid < 0, error('Cannot write summary: %s', jsonPath); end
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', jsonencode(report, PrettyPrint=true));
    clear cleaner
    if mode == "live"
        fid = fopen(fullfile(opts.OutputDir, 'capture.bin'), 'wb');
        if fid < 0, error('Cannot write raw capture'); end
        cleaner = onCleanup(@() fclose(fid));
        fwrite(fid, raw, 'uint8');
        clear cleaner
    end
end
fprintf('Frames: %d sample batches, %d records; CRC errors: %d; missing batches: %d; FIFO drops: %d\n', ...
    state.sample_frames, state.count, state.crc_errors, state.sequence_gaps, state.drop_increase);
fprintf('RTC markers: %d; START ACK: %d; STOP ACK: %d\n', ...
    numel(state.rtc), state.start_ack, state.stop_ack);
end

function state = newState()
state.buffer = uint8([]);
state.bytes_received = 0;
state.discarded = 0;
state.crc_errors = 0;
state.invalid_lengths = 0;
state.types = zeros(1,256);
state.sample_frames = 0;
state.sequence_gaps = 0;
state.previous_seq = NaN;
state.first_drops = NaN;
state.last_drops = NaN;
state.drop_increase = 0;
state.invalid_records = 0;
state.start_ack = false;
state.stop_ack = false;
state.rtc = struct('next_batch_seq',{},'time',{},'voltage_low',{}, ...
    'century_bit',{},'frame_seq',{},'sample_frames_seen',{});
state.invalid_rtc = 0;
state.capacity = 10000;
state.count = 0;
state.channel = zeros(1,state.capacity,'uint8');
state.raw = zeros(1,state.capacity,'uint16');
state.seq = zeros(1,state.capacity,'uint8');
state.value = zeros(1,state.capacity);
end

function state = feed(state, chunk)
chunk = reshape(uint8(chunk),1,[]);
state.bytes_received = state.bytes_received + numel(chunk);
state.buffer = [state.buffer, chunk];
while ~isempty(state.buffer)
    b = state.buffer;
    marker = find(b(1:end-1)==hex2dec('A5') & b(2:end)==hex2dec('5A'),1);
    if isempty(marker)
        keep = double(b(end)==hex2dec('A5'));
        state.discarded = state.discarded + numel(b) - keep;
        state.buffer = b(end-keep+1:end);
        return
    end
    if marker > 1
        state.discarded = state.discarded + marker - 1;
        b = b(marker:end);
        state.buffer = b;
    end
    if numel(b) < 5, return; end
    payloadLength = double(b(5));
    if payloadLength > 64
        state.invalid_lengths = state.invalid_lengths + 1;
        state.discarded = state.discarded + 1;
        state.buffer = b(2:end);
        continue
    end
    frameLength = 7 + payloadLength;
    if numel(b) < frameLength, return; end
    body = b(3:frameLength-2);
    receivedCrc = uint16(b(frameLength-1)) + bitshift(uint16(b(frameLength)),8);
    if receivedCrc ~= project1_crc16(body)
        state.crc_errors = state.crc_errors + 1;
        state.discarded = state.discarded + 1;
        state.buffer = b(2:end);
        continue
    end
    kind = b(3);
    seq = b(4);
    payload = b(6:frameLength-2);
    state.types(double(kind)+1) = state.types(double(kind)+1) + 1;
    if kind == hex2dec('83') && isequal(payload,uint8(1))
        state.start_ack = true;
    elseif kind == hex2dec('84') && isequal(payload,uint8(0))
        state.stop_ack = true;
    elseif (kind == hex2dec('90') || kind == hex2dec('91')) && payloadLength == 34
        state = addBatch(state, kind, seq, payload);
    elseif kind == hex2dec('92') && payloadLength == 8
        [rtc, valid] = decodeRtc(payload, seq, state.sample_frames);
        if valid, state.rtc(end+1) = rtc; else, state.invalid_rtc = state.invalid_rtc + 1; end %#ok<AGROW>
    end
    state.buffer = b(frameLength+1:end);
end
end

function state = addBatch(state, kind, seq, payload)
state.sample_frames = state.sample_frames + 1;
if ~isnan(state.previous_seq)
    state.sequence_gaps = state.sequence_gaps + mod(double(seq)-state.previous_seq-1,256);
end
state.previous_seq = double(seq);
drops = double(payload(1))*256 + double(payload(2));
if isnan(state.first_drops), state.first_drops = drops; end
if ~isnan(state.last_drops)
    state.drop_increase = state.drop_increase + mod(drops-state.last_drops,65536);
end
state.last_drops = drops;
if state.count + 16 > state.capacity
    state.capacity = state.capacity * 2;
    state.channel(state.capacity) = uint8(0);
    state.raw(state.capacity) = uint16(0);
    state.seq(state.capacity) = uint8(0);
    state.value(state.capacity) = 0;
end
words = uint16(payload(3:2:33))*256 + uint16(payload(4:2:34));
if kind == hex2dec('91')
    state.invalid_records = state.invalid_records + sum(bitand(words,uint16(hex2dec('3000'))) ~= 0);
    channels = uint8(bitshift(words,-14));
else
    channels = zeros(1,16,'uint8');
end
raw = bitand(words,uint16(4095));
values = double(raw)*3/4096;
temperature = channels == 0;
values(temperature) = double(raw(temperature))*503.975/4096 - 273.15;
ix = state.count + (1:16);
state.channel(ix) = channels;
state.raw(ix) = raw;
state.seq(ix) = seq;
state.value(ix) = values;
state.count = state.count + 16;
end

function [rtc, valid] = decodeRtc(payload, seq, seen)
rtc = struct('next_batch_seq',double(payload(1)),'time','', ...
    'voltage_low',logical(bitand(payload(2),128)), ...
    'century_bit',logical(bitand(payload(7),128)), ...
    'frame_seq',double(seq),'sample_frames_seen',seen);
masks = uint8([127 127 63 63 7 31 255]);
bytes = bitand(payload(2:8),masks);
lo = double(bitand(bytes,15));
hi = double(bitshift(bytes,-4));
valid = all(lo <= 9 & hi <= 9);
if ~valid, return; end
v = hi*10 + lo;
valid = v(1)<=59 && v(2)<=59 && v(3)<=23 && v(4)>=1 && ...
    v(5)<=6 && v(6)>=1 && v(6)<=12;
if ~valid, return; end
try
    t = datetime(2000+v(7),v(6),v(4),v(3),v(2),v(1));
    valid = year(t)==2000+v(7) && month(t)==v(6) && day(t)==v(4);
    if valid, rtc.time = char(string(t,'yyyy-MM-dd HH:mm:ss')); end
catch
    valid = false;
end
end

function out = sampleTable(state)
n = state.count;
names = ["temperature","VCCINT","VCCAUX","VCCBRAM"];
units = ["C","V","V","V"];
channel = state.channel(1:n);
channelNames = reshape(names(double(channel)+1),[],1);
channelUnits = reshape(units(double(channel)+1),[],1);
out = table((1:n)', state.seq(1:n)', channelNames, ...
    state.raw(1:n)', state.value(1:n)', channelUnits, ...
    'VariableNames',{'record_index','frame_seq','channel','raw','value','unit'});
end

function out = rtcTable(state)
r = state.rtc;
if isempty(r)
    out = table([], strings(0,1), [], [], [], [], 'VariableNames', ...
        {'next_batch_seq','time','voltage_low','century_bit','frame_seq','sample_frames_seen'});
else
    out = struct2table(r);
end
end

function report = makeReport(state, duration, mode, source)
report.mode = char(mode);
report.source = char(source);
report.duration_seconds = duration;
report.bytes_received = state.bytes_received;
counts = struct();
for kind = 0:255
    if state.types(kind+1) > 0
        counts.(sprintf('type_%02X',kind)) = state.types(kind+1);
    end
end
report.valid_frames_by_type = counts;
report.sample_frames = state.sample_frames;
report.samples_received = state.count;
names = ["temperature","VCCINT","VCCAUX","VCCBRAM"];
ranges = struct();
records = struct();
for k = 0:3
    ix = state.channel(1:state.count) == k;
    name = char(names(k+1));
    records.(name) = sum(ix);
    if any(ix)
        unit = 'V';
        if k==0, unit='C'; end
        values = state.value(1:state.count);
        ranges.(name) = struct('minimum',min(values(ix)), ...
            'maximum',max(values(ix)),'unit',unit);
    end
end
report.records_by_channel = records;
report.channel_ranges = ranges;
report.invalid_sample_records = state.invalid_records;
report.rtc_time_markers = state.rtc;
report.invalid_rtc_time_markers = state.invalid_rtc;
report.crc_errors = state.crc_errors;
report.invalid_lengths = state.invalid_lengths;
report.discarded_bytes_during_resync = state.discarded;
report.missing_sample_frames_by_sequence = state.sequence_gaps;
report.first_reported_drop_count = state.first_drops;
report.last_reported_drop_count = state.last_drops;
report.reported_drop_count_increase = state.drop_increase;
report.start_ack_received = state.start_ack;
report.stop_ack_received = state.stop_ack;
report.incomplete_bytes_at_end = numel(state.buffer);
if ~isnan(duration), report.sample_frames_per_second = state.sample_frames/duration;
else, report.sample_frames_per_second = NaN; end
end

function drawChannels(state)
persistent fig lines
if isempty(fig) || ~isgraphics(fig)
    fig = figure('Name','Project 1 — XADC four-channel monitor','NumberTitle','off');
    tiledlayout(fig,2,2);
    names = {'Chip temperature (C)','VCCINT (V)','VCCAUX (V)','VCCBRAM (V)'};
    lines = gobjects(1,4);
    for k=1:4
        ax = nexttile;
        lines(k) = plot(ax,nan,nan,'LineWidth',1);
        title(ax,names{k}); grid(ax,'on');
        xlabel(ax,'Stream record index');
    end
end
for k=0:3
    ix = find(state.channel(1:state.count)==k);
    ix = ix(max(1,numel(ix)-499):end);
    set(lines(k+1),'XData',ix,'YData',state.value(ix));
end
drawnow limitrate
end

function [raw,count] = appendRaw(raw,count,chunk)
chunk = reshape(uint8(chunk),1,[]);
needed = count+numel(chunk);
if needed > numel(raw)
    raw(max(needed,2*numel(raw))) = uint8(0);
end
raw(count+1:needed) = chunk;
count = needed;
end
