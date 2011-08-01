function [fenv, N] = freqenv( F, Ts, freq_divs, sweep_marks, t )
%[fenv, N] = freqenv( F, Ts, freq_divs, sweep_marks, t )
% 
% F is as generated in most other BatStack-related m-scripts, but in
% particular, loadgainrec.m.
% Ts is sample period (again, as in most other m-scripts).
%
% freq_divs specifies the divisions about which to consider frequency
% ranges (for energy integration). E.g., let K be the number of
% microphone channels (i.e., K := size(F,2) ). Then
%     freq_divs = [10e3 20e3 30e3]
% will cause fenv to have size 2xK, where the first row corresponds to
% signal integration after bandpass filtering between 10e3 and 20e3,
% and the second row corresponds to BPF between 20e3 and 30e3.
%
% sweep_marks is an optional argument specifying sweep times for some
% (or all) of the channels. Let N be the number of microphone channels
% (thus N := size(F, 2)). Then sweep_marks is a cell array with at
% most N elements, and each element is a vector with first element
% indicating the channel number and all subsequent elements being
% start and stop times for sweeps on that channel.  For example, if
%
%     sweep_marks = {[2, -.21, -.12, -.08, 0], [3]}
%
% then channel 2 has precisely two calibration sweeps, the first
% during the time -0.21 to -0.12, the second during the time -0.08 to
% 0, and channel 3 has no sweeps (i.e. it will receive all zeros in
% fenv and a warning will be printed); all remaining channels in F
% will be auto-marked using the getsweeps.m function.
%
% The argument t is optional and only defined if sweep_marks is given.
% It is the vector of times with respect to which time intervals in
% sweep_marks are given.  More explicitly, t is used to determine
% which indices in F the times in sweep_marks correspond to.
%
% N is a column vector of length equal to the number of microphone
% channels. Each element contains the number of gain calibration
% sweeps considered for a particular channel.
%
% Little error (or sanity)-checking. Beware!
%
%
% Scott Livingston  <slivingston@caltech.edu>
% May, June 2010; July 2011.


% Init
num_chans = size(F,2);
N = zeros(num_chans,1);
fenv = zeros(length(freq_divs)-1,num_chans);

% Parse arguments; create empty sweep_marks cell array if needed.
if nargin == 3
    sweep_marks = cell(0);
elseif nargin >= 5
    % ...type checking...
else
    error('Invalid invocation. Please consult freqenv helpdoc.')
end

% Buffer filter parameters
b = cell(length(freq_divs)-1,1);
a = b;
for f_ind = 1:length(freq_divs)-1
    [b{f_ind},a{f_ind}] = butter( 6, [freq_divs(f_ind) freq_divs(f_ind+1)]*Ts*2 );
end

% Build list of channels; fail if invalid channel numbers found;
% also map times in sweep_marks to indices in F columns.
sweep_mark_map = nan(num_chans,1);
for k = 1:length(sweep_marks)
    if isempty(sweep_marks{k}) ...
         || sweep_marks{k}(1) > num_chans || sweep_marks{k}(1) < 1 ...
         || rem(length(sweep_marks{k})-1, 2) ~= 0
        error('Given argument sweep_marks is not well formed.')
    end
    sweep_mark_map(sweep_marks{k}(1)) = k;
    for sweep_index = 2:2:length(sweep_marks{k})
        sweep_marks{k}(sweep_index:(sweep_index+1)) = [min(find(t > sweep_marks{k}(sweep_index))), max(find(t < sweep_marks{k}(sweep_index+1)))];
    end
end

% Do it!
for k = 1:num_chans

    % Look for channel in sweep_marks; if there, use it; else, try
    % auto-marking.
    if ~isnan(sweep_mark_map(k))
        if length(sweep_marks{sweep_mark_map(k)}) == 1
            fprintf( 'Warning: no gain cal sweeps specified for ch. %d.\n', k );
            continue
        end
        if length(sweep_marks{sweep_mark_map(k)}) < 3
            fprintf( 'Warning: insufficiently many gain cal sweeps specified for ch. %d.\n', k );
            continue
        end
        ch = struct('rise_pts', sweep_marks{sweep_mark_map(k)}(2:2:end), ...
                    'fall_pts', sweep_marks{sweep_mark_map(k)}(3:2:end));
    else
	[ch] = getsweeps( F(:,k) );
	if isempty(ch) || isempty(ch.rise_pts)
	    fprintf( 'Warning: no gain cal sweeps found for ch. %d.\n', k );
	    continue
	end
	if length(ch.rise_pts) < 3
	    fprintf( 'Warning: insufficiently many gain cal sweeps for ch. %d.\n', k );
	    continue
	end
    end

    N(k) = length(ch.rise_pts)-2;
    for sweep_ind = 1:N(k)
        xl = [ ch.rise_pts(sweep_ind+1)-ceil(10e-3/Ts), ch.rise_pts(sweep_ind+1)+ceil(80e-3/Ts) ];
	if xl(1) < 1 || xl(2) > length(F(:,k))
            N(k) = N(k) - 1;
            continue
        end
        for f_ind = 1:length(freq_divs)-1
            fenv(f_ind,k) = fenv(f_ind,k) + sqrt(mean( ( filtfilt(b{f_ind},a{f_ind},F(xl(1):xl(2),k)) ).^2 ));
        end
    end
    if N(k) > 0
        fenv(:,k) = fenv(:,k)/N(k); % mean
    end

end
