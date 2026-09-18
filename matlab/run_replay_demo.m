% Open this file in MATLAB and click Run. It replays the verified v8 capture.
here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(here);
addpath(here);
[report, samples] = project1_host("replay", ...
    fullfile(projectRoot,"fixtures","v8_short_uart.bin"), ...
    Plot=true, OutputDir=fullfile(projectRoot,"matlab_output"));
disp(report);
