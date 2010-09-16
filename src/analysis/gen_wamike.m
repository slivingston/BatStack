function [mike_pos] = gen_wamike( point_array, name_base, num_chan )
%[mike_pos] = gen_wamike( point_array, name_base, num_chan )
%
% We assume indexing begins at 1, i.e. microphone channels are numbered 1,
% 2, ..., num_chan.
%
% Any unfound channels have coordinates of NaN.
%
% Names for searching in point_array are constructed by osappending name_base
% with a zero-filled, width 2, mic channel index.
%
% Search is case-sensitive!
%
% point_array is as would be returned by lc3d.m (in the BAMF_tools
% subversion repository. We further assume units of mm in point_array
% trajectories (whence we convert to meters).
%
%
% Scott Livingston  <slivingston@caltech.edu>
% July 2010.

mike_pos = nan(num_chan,3);
len_pa = length(point_array);

for k = 1:num_chan
    this_chan_name = sprintf( [name_base '%02d'], k );
    for j = 1:len_pa
        if strcmp(point_array{j}.name, this_chan_name)
            mike_pos(k,:) = mean(point_array{j}.traj)./1e3; % ...and convert to meters
            break
        end
    end
end
