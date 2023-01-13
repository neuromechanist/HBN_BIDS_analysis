function fEMG = emgfilt(emg, freq)

error(nargchk(1, 2, nargin));

% if not specified, set EMG freq for Delsys Trigno system
% lowpass = 450 Hz; highpass = 20 Hz;
% sampling freq = 2000; for delsys
% sampling freq = 1000; for vicon

if nargin < 2, 
    freq.lo = 450; freq.hi = 20;
    freq.sampling = 1000; 
end

[b,a] = butter(4,freq.hi/freq.sampling*2,'high');
[bl,al] = butter(4,freq.lo/freq.sampling*2);

emghi = filtfilt(b,a,emg);
emgrect = abs(emghi);
fEMG = filtfilt(bl,al,emgrect);