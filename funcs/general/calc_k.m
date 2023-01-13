function k = calc_k(S, N)

% to find N stable components from N-channel data
% target k = 60-70
% k = S/N^2 where S = number of samples and N = number of channels
% k has units of pts/weight

k = S/N^2;