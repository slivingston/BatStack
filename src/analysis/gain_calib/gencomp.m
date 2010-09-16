function [G] = gencomp( freq_divs, fenv )
%[G] = gencomp( freq_divs, fenv )
%
% G defines transfer function magnitude compensation required for
% comparison of data across microphone channels.
%
% Each row corresponds to a center frequency, which is specified in
% the first column. Each subsequent column has factors corresponding
% to a particular mic channel (assumed to be in order, or at least
% matching the order of given fenv matrix). E.g., the compensation
% factor for mic channel 4 at frequency G(6,1) is G(6,5).
%
% For specs on freq_divs and fenv, see freqenv m-script help doc.
%
%
% Scott Livingston  <slivingston@caltech.edu>
% June 2010.


num_freqs = length(freq_divs)-1;
num_chans = size(fenv,2);

% Allocate space
G = zeros(num_freqs,num_chans+1);

% Define center frequencies to be midpoints across freq_divs intervals.
% And, calculate compensation factors, populate G
for k = 1:num_freqs
    G(k,1) = (freq_divs(k+1)+freq_divs(k))/2;
    [max_mag, max_ind] = max( fenv(k,:) );
    for j = 1:num_chans
        if fenv(k,j) > eps
            G(k,j+1) = max_mag/fenv(k,j);
        else
            G(k,j+1) = 0; % response too small; assume zero.
        end
    end
    G(k,max_ind+1) = 1; % Ensure reference channel for this freq has factor of precisely 1.
end
