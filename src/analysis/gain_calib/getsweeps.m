function [ch,x] = getsweeps( x );
%function [ch,x] = getsweeps( x );
%
%   ch - structure with fields:
%          rise_pts, fall_pts;
%    x - the filtered and smoothed waveform is returned.
%
% NOTES: - Sample period is assumed to be 3.75 microseconds.
%
% Scott Livingston
%
% Dec 2009, May 2010.


% Various globals for easy reference
Ts = 3.75e-6; % sample period
ths = 0.13;
min_dur = .01; % 10 ms


% Check that x has already been limited to 0 to 3.3 V range:
if ~isempty(find(x > 100))
   x = x*3.3/1023; % Assume 10 bit sample width and Vref = 3.3V.
end

% Remove the DC offset
x = x - mean(x);

% BPF: Butterworth, 4th order, 10 kHz - 130 kHz
[b,a] = butter( 2, [10e3 130e3].*Ts*2 );
x = filter( b, a, x );

% Rectify
x = abs(x);

% Convolve with rectangle
rect = ones(floor(.0005/Ts),1); % 0.5 ms rectangular window
x = conv( x, rect );
x(1:floor((length(rect)-1)/2)) = [];
x(end-(ceil((length(rect)-1)/2)-1):end) = [];

% Normalize
x = x/max(x);

% Apply threshold and determine intervals
I = find(x > ths);
Id = find(diff(I) > 1);
ch.rise_pts = zeros(length(Id)+1,1);
ch.fall_pts = ch.rise_pts;
ch.rise_pts(1) = I(1);
ch.rise_pts(2:end) = I(Id+1);
ch.fall_pts(end) = I(end);
ch.fall_pts(1:end-1) = I(Id);

% Finally, ignore intervals that are too brief to have been a
% calibration sweep.
I = find((ch.fall_pts-ch.rise_pts)*Ts < min_dur);
ch.rise_pts(I) = [];
ch.fall_pts(I) = [];
