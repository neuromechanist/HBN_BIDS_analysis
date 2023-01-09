function [Y f] = emgfreqspec(emg, Fs, fc_hi)

error(nargchk(2, 2, nargin));

% high pass filter to attenuate low freq components
if nargin < 3, 
    fc_hi = 20;
end
[b,a] = butter(4,fc_hi/Fs*2,'high');
emghi = filtfilt(b,a,emg);

L = length(emghi);
NFFT = 2^nextpow2(L); % Next power of 2 from length of emg
Y = fft(emghi, NFFT)/L;
f = Fs/2*linspace(0,1,NFFT/2+1);

if nargout == 0
    figure
    plot(f,2*abs(Y(1:NFFT/2+1)))
    set(gca, 'xlim', [0 Fs/2]);
    title('Single-sided amplitude spectrum of emg');
    ylabel('|EMGfft(f)|');
    xlabel('Freq (Hz)');
end