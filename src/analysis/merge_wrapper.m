function [F,t,Ts] = merge_wrapper( bname, stack_addrs, trial_nums, chan_map, fname, chan_span )
%[F,t,Ts] = merge_wrapper( bname, stack_addrs, trial_nums, chan_map, fname[, chan_span] )
%
% Wraps functionality of merge2array, waread and fleshout, and further, 
% saves the result to a file following the format of bin files saved with 
% merge2array (cf. help doc of merge2array for specs) but in which 
% channels are sequential (e.g., 1 to 16, in order), whence chan_map is no 
% longer necessary (in particular, it suffices to know the number of 
% channels). 
%
% Note that this m-script writes to disk while functioning. If you abort 
% early, then there may be some file residue left, in which case DO NOT 
% USE IT; it is likely corrupted in some way.
%
% chan_span specifies the range of channel numbers. Default value is [1 16], i.e. 16 mic channels.
%
%
% Scott Livingston  <slivingston@caltech.edu>
% 22 May 2010.


if nargin ~= 6
    chan_span = [1 16];
    if nargin ~= 5
        fprintf( 'Not enough arguments.\n' );
        F = [];
        t = [];
        Ts = -1;
        return
    end
end

merge2array( bname, stack_addrs, trial_nums, chan_map, fname );
clear chan_map;
[F, chan_map, t, Ts] = waread( fname );
F = fleshout( F, chan_map, chan_span );
chan_map = [chan_span(1):chan_span(2)]';

% Save the result to disk
fd = fopen( fname, 'w' );
fwrite( fd, [chan_map; 255; 255], 'uint8' );
for j = chan_span(1):chan_span(2)
    fwrite( fd, F(:,j-chan_span(1)+1), 'uint16' );
    fwrite( fd, [255; 255], 'uint8' );
end
fclose(fd);
