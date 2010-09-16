function [PSD_list] = psdbeam( F, t_first, fmin, fmax, t_start, dur, Ts )
%[PSD_list] = psdbeam( F, t_first, fmin, fmax, t_start, dur[, Ts] )
%
% Returns list of power spectral densities (as calculated by
% Matlab spectrogram function) within the given frequency range
% and for a time window beginning at t_start (length equal to
% number of microphone channels) and global duration of dur.
% Time is in seconds. t_first is the time corresponding to the
% first sample (common and across all channels), i.e., F(1,:).
%
% Sample period Ts is optional and defaults to 3.75 us.
%
% Note that length(PSD_list) = length(t_start) = size(F,2).
% Further note that DC offsets are removed from all channels
% before calculating PSDs.
%
%
% Scott Livingston  <slivingston@caltech.edu>
% May 2010.


if nargin < 7
    Ts = 3.75e-6; % sample period, in seconds
end

num_chans = length(t_start);
PSD_list = zeros(num_chans,1);

dur_ind = ceil(dur/Ts);

for k = 1:num_chans

    ind_start = max(ceil((t_start(k)-t_first)/Ts),1);
    [S,Freq,T,P] = spectrogram(F(ind_start:ind_start+dur_ind,k)-mean(F(ind_start:ind_start+dur_ind,k)), 128,120,256, 1/Ts);
    I = find(Freq <= fmin & Freq <= fmax);
    PSD_list(k) = max(max(P(I,:)));

end
