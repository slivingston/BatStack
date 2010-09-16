function [F,t,Ts] = loadgainrec( bname, stack_addrs, chan_map, trial_map )
%function [F,t,Ts] = loadgainrec( bname, stack_addrs, chan_map, trial_map )
%
% NOTES: - F has size MxN, where N is the total number of microphone
%          channels and M is the number of samples per trial
%          recording. Note that chan_map is used to ensure that
%          ordering of columns in F matches microphone channel
%          ordering, i.e. gain calibration for (global) channel 1 is
%          in F(:,1), channel 2 is in F(:,2), and so on.
%
%          Note further that F is filled out to maximum number in chan_map matrix.
%          Channels for which no data is specified have all zero columns
%
%        - chan_map is as defined elsewhere, e.g. see notes in merge2array.m
%
%        - trial_map is a Kx4 matrix, where each row corresponds to one
%          BatStack (with ordering matching that of the given list of
%          Stack addresses stack_addrs), and each column contains the
%          value of the trial number in which the corresponding
%          channel of a particular BatStack was tested
%
%          E.g., trial_map = [4 2 5 1; 5 2 1 5],
%          indicates that for BatStack stack_addrs(1), the file for gain
%          calibration of (local) channel 1 has trial number 4,
%          channel 2 has trial number 2, and so on. Similarly, for the
%          BatStack with address stack_addrs(2), gain calibration
%          information for its (local) channel 1 is in a "trial 5"
%          file, channel 2 has trial number 2, and so on.
%
% The mapping scheme may be confusing at first, but it provides
% greatest flexibility and allows use in a back-end later.
%
%
% Scott Livingston  <slivingston@caltech.edu>
% May 2010.


% Switch address lists that are column vectors to row vectors.
addr_list_sz = size(stack_addrs);
if addr_list_sz(1) > addr_list_sz(2)
   stack_addrs = stack_addrs';
end

F = zeros(2^20, max(max(chan_map)));

for bs_id_ind = 1:length(stack_addrs)

    for trial_ind = 1:size(trial_map,2)
        
        if trial_map(bs_id_ind,trial_ind) <= 0 || chan_map(bs_id_ind,trial_ind) <= 0
            continue % Ignore unimplemented array channels
        end

        fd = fopen( sprintf( '%s_%02x_trial%02d.bin', bname, stack_addrs(bs_id_ind), trial_map(bs_id_ind,trial_ind) ), 'r' );
        if fd == -1
            fprintf( 'Error while reading file: %s\n', sprintf( '%s_%02x_trial%02d.bin', bname, stack_addrs(bs_id_ind), trial_map(bs_id_ind,trial_ind) ) );
            return
        end
        fprintf( 'Reading from %s...\n', sprintf( '%s_%02x_trial%02d.bin', bname, stack_addrs(bs_id_ind), trial_map(bs_id_ind,trial_ind) ) );
        %fflush(stdout); % Otherwise, Octave buffers until script completion.

        x = fread( fd, 'uint16' );
        fclose(fd);

    	F(:,chan_map(bs_id_ind,trial_ind)) = x(trial_ind:4:end)';

    end
end

% Assume sample period of 3.75 us
Ts = 3.75e-6;
% ..and an end trigger
t = (1-length(F(:,1)):0)'*Ts;
