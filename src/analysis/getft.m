function [ch_fft] = getft( ch_raw, src_traj, mic_pos, mic_gainprofile, time_width, ref_time )
%[ch_fft] = getft( ch_raw, src_traj, mic_pos, mic_gainprofile, time_width, ref_time )
%
% Performs a subset of the genbeam m-script routine, which is useful for
% simply extracting corresponding spectral traces from all mic channels.
% See help documentation in genbeam.m for details and related notes.
%
% NOTES: - ch_fft is a cell array with one element per microphone
%          channel (same ordering as in mic_pos matrix; cf. genbeam
%          help doc). Each cell contains an Nx2 matrix, A, where the
%          first column is frequency, the second column is DFT
%          magnitude, and the third column is the compensated spectrum
%          (based on the given mic_gainprofile). This should be
%          directly comparable across channels and Stacks.
%
%
% Scott Livingston
% 6 Dec 2009


% Convenience constants
Ts = 3.75e-6; % sample period
vid_fps = 250; % frames per second; video positioning system
spd_sound = 343; % m/s
temp = 25; % deg C
rh = 50; % relative humidity (percentile)

num_channels = length(mic_pos);

% Perform any necessary clean up of given raw channel data
for k = 1:num_channels
    if ~isempty(find(ch_raw{k} > 100,1))
        ch_raw{k} = ch_raw{k}*3.3/1023; % Assume 10 bit sample width and Vref = 3.3V.
    end

    % Remove the DC offset
    ch_raw{k} = ch_raw{k} - mean(ch_raw{k});
end


% Calculate (or estimate) position of sound source at time of emission
if size(src_traj,1) > 1
    min_ind = findsrc( src_traj, mic_pos(ref_time(2),:), ref_time(1), vid_fps, spd_sound );
    call_time = (min_ind-1)/vid_fps;
    src_pos = src_traj( max(floor(call_time*vid_fps),1), : );
else
    src_pos = src_traj;
    call_time = ref_time(1) - norm(src_pos-mic_pos(ref_time(2),:),2)/spd_sound; % Corresponding time at the source.
end

% Calculate start index for each mic channel, given reference; and 
% convert time_width to a count of indices.
st_indices = zeros( num_channels, 1 );
st_indices(ref_time(2)) = max(floor(ref_time(1)/Ts),1);
flight_dist = zeros(num_channels,1);
for k = 1:num_channels
    flight_dist(k) = norm(src_pos-mic_pos(k,:),2);
    st_indices(k) = max( floor(( call_time + flight_dist(k)/spd_sound )/Ts), 1 );
end

% Duration of signal to consider, in indices.
ind_len = ceil(time_width/Ts);

% Generate the big cell-array-o-FFTs; one element per channel.

ch_fft = cell(num_channels,1);
k = 0; % mic channel counter
for bs_ind = 1:length(mic_gainprofile)
    for mic_ind = 1:4 % Assumes all four channels active and valid
        k = k+1;
        NFFT = 2*(length(mic_gainprofile{bs_ind}.ch{mic_ind}.A)-1);
        ch_fft{k}.A = zeros(NFFT/2+1,3);
        tmp = fft(ch_raw{k}(st_indices(k):(st_indices(k)+ind_len-1)),NFFT)/ind_len;
        ch_fft{k}.A(:,1) = mic_gainprofile{bs_ind}.ch{mic_ind}.A(:,1);
        ch_fft{k}.A(:,2) = 2*abs(tmp(1:NFFT/2+1));
        ch_fft{k}.A(:,3) = ch_fft{k}.A(:,2) .* mic_gainprofile{bs_ind}.ch{mic_ind}.A_comp(:,2);
    end
end
