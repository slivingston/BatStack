% function [hdr,trials,t] = loadsdtrials( fname, trials_to_load )
%
% Matlab function for reading a BatStack-related MMC/SD card data file.
%
% NOTES: - More documentation please!
%        - Assumes 4 channels at 250 ksps and 4 MWord recording length
%          each. Further assumes sample width is 10 bits and (linearly)
%          spans 3.3 V.
%        - Returns a time vector for convenience.
%        - trials_to_load is a vector of trial numbers to load; the
%          cell entries in the "trials" cell array which correspond
%          to unloaded trials contain empty matrices. Default behavior,
%          i.e., when no trials_to_load parameter is given, is to
%          load all trials in the data file.
%        - If trials_to_load parameter is an empty vector, then only
%          the data file header is read and returned.
%        - Each trial is organized as an Nx4 matrix, where each column
%          corresponds to one of the microphone channels, and each row
%          to a sample (all samples in a row occurred at the same time).
%
% Scott Livingston <slivingston@caltech.edu>
% October-November 2009.

function [hdr,trials,t] = loadsdtrials( fname, trials_to_load )

% Handle a select-file GUI
if nargin == 0
	[fname, pname] = uigetfile( '*.*', 'Select a SD/MMC data file.' );
	if isequal(fname,0)
		return % Do nothing
	end
	fname = [pname fname]; % Convert file name to fully resolved path
end

fid = fopen( fname, 'r' );
if fid == -1 % Failed to open file
	error( 'Could not open file, %s\n', fname );
	return
end

% Default to loading of all trials in data file.
if nargin < 2
	trials_to_load = -1; % "Load all trials" flag
end

% Read header parameters
hdr = fread(fid,3,'uint32');
fseek(fid,512,'bof');

% If no trials are to be read, simply return header
if isempty(trials_to_load)
	trials = [];
	t = [];
	fclose(fid);
	return
end

% Minor error checking:
if hdr(2) < 0 % Negative number of trials?
	fclose( fid );
	error( 'Number of trials in data file header is negative! Read %d\n', hdr(2) );
	return
end

% Read and preprocess the trial recordings
for k = 1:hdr(2)
	if ~isempty(find(k == trials_to_load)) || (length(trials_to_load) == 1 && trials_to_load == -1)
		[trials{k}, count] = fread(fid,4*2^20,'uint16');
		if count < 4*2^20
			fclose( fid );
			error( 'Failed to read entire trial %d; aborting' );
			return
		end
	else
		trials{k} = [];
		fseek( fid, 8*2^20, 'cof' );
	end

	fseek(fid,512,'cof');
	trials{k} = trials{k}/1023*3.3; % Scale to ADC input voltage range
	trial_tmp = zeros( length(trials{trials_to_load(1)}(1:4:end)), 4 );
	for i = 2:4
		trials_tmp(:,i-1) = trials{k}(i:4:end);
	end
	trials_tmp(:,4) = trials{k}(1:4:end);
	trials{k} = [];
	trials{k} = trials_tmp;
end

% Generate corresponding time vector
if hdr(2) > 0
	if length(trials_to_load) == 1 && trials_to_load == -1 % Default behavior (i.e., load all trials)?
		trials_to_load = 1;
	end
	t = (0:(length(trials{trials_to_load(1)}(1:4:end))-1))/250e3;
else
	t = []; % No trials...
end

fclose( fid );
