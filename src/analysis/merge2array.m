function [x,t,Ts] = merge2array( bname, stack_addrs, trial_nums, chan_map, fname )
%[x,t,Ts] = merge2array( bname, stack_addrs, trial_nums, chan_map, fname )
%
% Combine data files across selected Stacks and trial numbers, organize
% according to chan_map, and save the result to a file named fname.
% Channel data is stored in blocks of samples, beginning with first channel.
% Each sample is 10 bits wide (at time of writing) and thus stored in a uint16 type.
% The upper, unused bits (i.e. upper 6 bits) are set to 0.  Blocks of channel
% data are separated by 0xFF 0xFF.
% 
% The first part of each file begins with a channel number string specifying which
% channels have data in this file. The end of the string is indicated by two 0xFF 0xFF
% bytes. Channel numbering must be of type uint8.
%
% chan_map is a matrix of size Nx4, where N is the number of BatStacks considered.
% The row ordering matches the order of stack_addrs.
% Within a row, for each column, the value indicates the channel number to
% which the corresponding channel of the current BatStack should be mapped.
% For example,
% chan_maps(2,:) = [4 2 5 7]
% means the BatStack with address stack_addrs(2) (and name base bname) will
% have its first channel data stored as "channel 4", its second channel as
% "channel 2", and so on.
%
% This script returns the same values as would be returned by loadtrialmash.m
%
%
% Scott Livingston  <slivingston@caltech.edu>
% 14 May 2010.

D = dir(fname);
if ~isempty(D)
    fprintf( 'Error: %s already exists. Please first delete it manually, if desired.\n', fname );
    x = [];
    t = [];
    Ts = [];
    return
end

% Switch address lists that are column vectors to row vectors.
addr_list_sz = size(stack_addrs);
if addr_list_sz(1) > addr_list_sz(2)
   stack_addrs = stack_addrs';
end

x = cell(0);

fprintf( 'Buffering data...\n' );
scounter = 0;
for bs_id_ind = 1:length(stack_addrs)

    fd = fopen( sprintf( '%s_%02x_trial%02d.bin', bname, stack_addrs(bs_id_ind), trial_nums(bs_id_ind) ), 'r' );
    if fd == -1
        fprintf( 'Error while reading file: %s\n', sprintf( '%s_%02x_trial%02d.bin', bname, stack_addrs(bs_id_ind), trial_nums(bs_id_ind) ) );
        x = cell(0);
        return
    end
    fprintf( 'Reading from %s...', sprintf( '%s_%02x_trial%02d.bin', bname, stack_addrs(bs_id_ind), trial_nums(bs_id_ind) ) );
    %fflush(stdout); % Otherwise, Octave buffers until script completion.

    raw = fread( fd, 'uint16' );

    for ch_ind = 1:4
        scounter = scounter + 1;
        x{scounter} = raw(ch_ind:4:end);
    end

    fclose(fd);
    fprintf( 'Done.\n' );
    %fflush(stdout); % Otherwise, Octave buffers until script completion.

end
% Assume sample period of 3.75 us
Ts = 3.75e-6;
% ..and an end trigger
t = (1-length(x{1}):0)*Ts;

fd = fopen( fname, 'w' );

% write channel table
chan_map = chan_map';
fwrite(fd, [chan_map(:); 255; 255], 'uint8' );

% dump data
for j = 1:scounter
    fwrite(fd, x{j}, 'uint16' );
    fwrite(fd, [255;255], 'uint8' );
end

fclose(fd);
