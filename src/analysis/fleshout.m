function [F] = fleshout( F, chan_map, chan_span )
%[F] = fleshout( F, chan_map[, chan_span] )
%
% chan_map is the channel mapping for columns in F, as returned from waread function.
% chan_span, if given, specifies start and ending channel numbers, e.g. chan_span = [1 20]
% means there are mic channels 1 through 20. Default is chan_span = [1 16].
%
% The result is F expanded to have number of columns matching total number of mic channels,
% and each column corresponds to a mic channel, as per chan_map. I.e., after calling
% this function, you get an F which organizes channel data such that a channel map (chan_map)
% is no longer needed. Empty/unused channels yield columns of zero.
%
%
% Scott Livingston   <slivingston@caltech.edu>
% May 2010.


% Default arguments
if nargin < 3
    chan_span = [1 16];
end

F_orig = F;
num_samps = size(F_orig,1);
F = zeros(num_samps, chan_span(2)-chan_span(1)+1);
for k = 1:length(chan_map)
    F(:,chan_map(k)) = F_orig(:,k);
end
