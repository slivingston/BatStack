function [fenv, N] = freqenv( F, Ts, freq_divs )
%[fenv, N] = freqenv( F, Ts, freq_divs )
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
% N is a column vector of length equal to the number of microphone
% channels. Each element contains the number of gain calibration
% sweeps considered for a particular channel.
%
% Little or no error (or sanity)-checking. Beware!
%
%
% Scott Livingston  <slivingston@caltech.edu>
% May, June 2010.


% Init
num_chans = size(F,2);
N = zeros(num_chans,1);
fenv = zeros(length(freq_divs)-1,num_chans);

% Buffer filter parameters
b = cell(length(freq_divs)-1,1);
a = b;
for f_ind = 1:length(freq_divs)-1
    [b{f_ind},a{f_ind}] = butter( 6, [freq_divs(f_ind) freq_divs(f_ind+1)]*Ts*2 );
end

% Do it!
for k = 1:num_chans

    [ch] = getsweeps( F(:,k) );
    if isempty(ch) || isempty(ch.rise_pts)
        fprintf( 'Warning: no gain cal sweeps found for ch. %d.\n', k );
	continue
    end
    if length(ch.rise_pts) < 3
        fprintf( 'Warning: insufficiently many gain cal sweeps for ch. %d.\n', k );
        continue
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
