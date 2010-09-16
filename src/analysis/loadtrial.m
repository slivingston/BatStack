function [ch_raw,t,Ts] = loadtrial( bname, stack_addrs, trial_num )
%function [ch_raw,t,Ts] = loadtrial( bname, stack_addrs, trial_num )
%
% NOTES: - ch_raw is filled sequentially as each channel in each stack
%          (given stack_addrs) is read.
%
%
% Scott Livingston
% Dec 2009, May 2010.


% Switch address lists that are column vectors to row vectors.
addr_list_sz = size(stack_addrs);
if addr_list_sz(1) > addr_list_sz(2)
   stack_addrs = stack_addrs';
end

ch_raw = cell(0);

scounter = 0;
for bs_id = stack_addrs

    fd = fopen( sprintf( '%s_%02x_trial%02d.bin', bname, bs_id, trial_num ), 'r' );
    if fd == -1
        fprintf( 'Error while reading file: %s\n', sprintf( '%s_%02x_trial%02d.bin', bname, bs_id, trial_num ) );
        ch_raw = cell(0);
        return
    end
    fprintf( 'Reading from %s...', sprintf( '%s_%02x_trial%02d.bin', bname, bs_id, trial_num ) );
    %fflush(stdout); % Otherwise, Octave buffers until script completion.

    x = fread( fd, 'uint16' );

    for ch_ind = 1:4
        scounter = scounter + 1;
        ch_raw{scounter} = x(ch_ind:4:end);
    end

    fclose(fd);
    fprintf( 'Done.\n' );
    %fflush(stdout); % Otherwise, Octave buffers until script completion.

end

% Assume sample period of 3.75 us
Ts = 3.75e-6;
% ..and an end trigger
t = (1-length(ch_raw{1}):0)'*Ts;

