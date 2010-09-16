function [mic_gainprofile] = getgp( bname, stack_addrs );
%
% NOTES: - Assumes trial number corresponds to target channel for each
%          BatStack, e.g., in trial 1, mic channel 1 was targetted for
%          calibration. Further assumes that all four channels are
%          valid in each considered Stack.
%
%        - bname is the base filename whence to derive full names.
%          stack_addr is a vector of BatStack addresses to use; note
%          that these are later expressed as 2 hex digits but should
%          be given in decimal; e.g., 255 yields "ff" for filename
%          searching purposes.
%          
%        - mic_gainprofile is a cell array with one element per Stack.
%          Format is
%            stack_addr - corresponding BatStack address;
%                    ch - cell array with one element per mic channel,
%                         each containing matrix ``A'' as defined in the
%                         avgsweep m-script, and ``A_comp'' as defined
%                         in the gencomp m-script.
%
%        - On error, an empty cell array is returned.
%
% Scott Livingston
% 2 Dec 2009


% Switch address lists that are column vectors to row vectors.
addr_list_sz = size(stack_addrs);
if addr_list_sz(1) > addr_list_sz(2)
   stack_addrs = stack_addrs';
end

mic_gainprofile = cell(0);

% Main loop - step through given address list
scounter = 0;
for bs_id = stack_addrs

    scounter = scounter + 1;
    mic_gainprofile{scounter}.stack_addr = bs_id;

    for ch_ind = 1:4

    	fd = fopen( sprintf( '%s_%02x_trial%02d.bin', bname, bs_id, ch_ind ), 'r' );
	if fd == -1
	   mic_gainprofile = cell(0);
	   return
	end

        x = fread( fd, 'uint16' );
        ch_meas = getsweeps( x(ch_ind:4:end) );
        mic_gainprofile{scounter}.ch{ch_ind}.A = avgsweep( x(ch_ind:4:end), ch_meas.rise_pts(2:end-1), ch_meas.fall_pts(2:end-1) );
        gp_ref = zeros(length(mic_gainprofile{scounter}.ch{ch_ind}.A),2);
        gp_ref(:,1) = mic_gainprofile{scounter}.ch{ch_ind}.A(:,1);
        gp_ref(:,2) = 0.02*ones(length(gp_ref),1);
        mic_gainprofile{scounter}.ch{ch_ind}.A_comp = gencomp( mic_gainprofile{scounter}.ch{ch_ind}.A, gp_ref, [10e3 100e3] );

	fclose(fd);

    end

end
