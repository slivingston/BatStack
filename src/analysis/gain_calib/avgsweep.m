function [A,n] = avgsweep( x, rise_pts, fall_pts )
%function [A,n] = avgsweep( x, rise_pts, fall_pts )
%
%   Returns an Nx3 matrix, A, where
%    - column 1 is frequency,
%    - column 2 is mean magnitude (at this freq)
%    - column 3 is variance of magnitude (at this freq)
%   and an integer n, the number of sweeps considered.
%   Note that in current method, n = length(rise_pts).
%
% NOTES: - Given x should be original (or possibly scaled
%          to voltage range, rather than uint16 value as
%          stored), in particular, NOT the filtered and
%          smoothed envelope given by getsweeps function.
%
%        - This m-script is currently memory intensive;
%          It generates FFTs for every sweep (based on
%          pairs of rise and fall points), expands them
%          to have common width (using cubic spline
%          interpolation), and then finds means and
%          variance with respect to frequency.
%
% Scott Livingston <slivingston@caltech.edu>
%
% Began: 1 Dec 2009.


% Various globals for easy reference
Ts = 3.75e-6; % sample period


% Check that x has already been limited to 0 to 3.3 V range:
if ~isempty(find(x > 100))
   x = x*3.3/1023; % Assume 10 bit sample width and Vref = 3.3V.
end

% Remove the DC offset
x = x - mean(x);

% Find next power of 2 above longest interval length;
% only knowing the longest interval is sufficient, but using
% a power of 2 substantially improves FFT algorithm speed.
max_intlen = max(fall_pts-rise_pts);
NFFT = 2^nextpow2( max_intlen );


% Calculate the DFT of each sweep interval and several statistics

f = 1/(2*Ts)*linspace(0,1,NFFT/2+1); % Frequencies (Hz)
fft_results = zeros(length(rise_pts),length(f));
for k = 1:length(rise_pts)
    tmp = fft(x(rise_pts(k):fall_pts(k)),NFFT)/length(rise_pts(k):fall_pts(k));
    fft_results(k,:) = 2*abs(tmp(1:NFFT/2+1));
end

A = zeros(length(f),3);
A(:,1) = f';
A(:,2) = mean(fft_results,1)';
A(:,3) = var(fft_results,1)';

n = size(fft_results);
n = n(1);
