function genafile( fname, bname, stack_addrs, trial_nums, chan_map, params, num_chans, ver_num )
%genafile( fname, bname, stack_addrs, trial_nums, chan_map[, params, num_chans, ver_num] )
%
% Generate an array data file, called fname, conforming to the standard format; confer
% the BatStack reference manual.
%
% ver_num specifies the file format version to conform to. If not
% specified, it defaults to the most current supported format.
%
% params is a structure containing fields relevant to the file header. The
% fields recognized depend on the format version. Any missing fields have
% empty (or default, depending on format specs) values stored in the file
% header.
%
% params fields recognized may be
%   recording_date - (u16) same as used in flash memory header on
%       individual BatStacks; if given as a string, it must be of the form
%       'YYYY-MM-DD' (where '-' is the significant dividing token).
%   trial_number - (obvious)
%   sample_period - (float) note that this is converted to an integral
%       format in units of 10 nanoseconds.
%   post_trigger_samps - number of samples (per channel) after the trigger;
%       e.g., value of 0 indicates an end trigger.
%   notes - (string) comments on this trial/array data.
%
% (Note that genafile takes nearly identical arguments to merge_wrapper.)
% This function depends on loadtrialmash.m.
%
% num_chans optionally specifies the number of channels in the system,
% whereby channels for which no data is available in the considered trial
% recordings are set to 0 (constant). The default number of channels is
% max(chan_map(:)). The goal here is to facilitate recordings in which some
% subset of a known working (and calibrated) microphone array is used.
%
% The sister m-function to this script is loadafile.m
%
%
% Scott Livingston  <slivingston@caltech.edu>
% June 2010.


if nargin < 8
    ver_num = 1;
end
if nargin < 7
    num_chans = max(chan_map(:));
end
if nargin < 6
    params = struct; % Just create an empty structure here to simplify the
                     % remaining code.
end

% At the time of writing, there is only one file format version, so we do
% not use any conditional switching here. Future editions will need to add
% such version-specific routines.

% ...
fprintf( 'Using file format version %d\n', ver_num );

% Check if desired filename is already in use; if yes, then block to avoid
% overwriting.
D = dir(fname);
if ~isempty(D)
    fprintf( 'Error: %s already exists. You must manually delete the\npresent file if you wish to use this name for a new array data file.', fname );
    return
end

[x,t,Ts] = loadtrialmash( bname, stack_addrs, trial_nums );
if isempty(x)
    error( 'Failed to load raw (unsorted) trial data.' );
end

if isfield( params, 'sample_period' ) % Use given sample period if available.
    Ts = params.sample_period;
end
fprintf( 'Sample period: %.4f us\n', Ts*1e6 );
Ts = Ts*1e8; % Convert sample period to units of 10 ns.

% Attempt to process recording date, if given.
if isfield( params, 'recording_date' )
    fprintf( 'Recording date: ' );
    if isstr( params.recording_date )
        recording_date = gendate( params.recording_date );
        fprintf( '(%s) ', params.recording_date );
    else
        recording_date = params.recording_date;
    end
    fprintf( '0x%04X\n', recording_date );
else
    recording_date = 0; % Default to empty.
end

% Trial number if available
if isfield( params, 'trial_number' )
    if isstr( params.trial_number )
        trial_num = str2num( params.trial_number );
    else
        trial_num = params.trial_number;
    end
    fprintf( 'Trial number: %d\n', trial_num );
else
    trial_num = 0; % Default
end

% Post-trigger samples
if isfield( params, 'post_trigger_samps' )
    post_triglen = params.post_trigger_samps;
else
    post_triglen = 0;
end
fprintf( 'Post-trigger length (in samples per channel): %d\n', post_triglen );

% Notes
if isfield( params, 'notes' ) && isstr(params.notes)
    notes = params.notes;
    if length(notes)>128
        notes = notes(1:128); % Trim overly long notes strings.
    elseif length(notes) < 128
        pad = zeros(128-length(notes),1);
        if size(notes,1) > size(notes,2)
            notes = [notes; pad];
        else
            notes = [notes pad'];
        end
    end
    fprintf( 'Notes: %s\n', notes );
else
    notes = zeros(128,1); % Empty notes string, zero-filled.
end

% Echo number of channels, just to be verbose
fprintf( 'Number of mic channels: %d\n', num_chans );

% Do the damn thing
fd = fopen( fname, 'w' );
if fd == -1
    error( 'Failed to open file %s for writing.', fname );
end

% Since we have high confidence in a successful file generation at this
% point, let us now organize the raw, unordered array recordings read
% earlier.
F = zeros(length(x{1}),num_chans);
for k = 1:length(chan_map(:))
    if chan_map(k) > 0
        F(:,chan_map(k)) = x{k};
    end
end
clear x t; % Free up some heap

% Header
nb = fwrite(fd, ver_num, 'uint8' );
nb = nb + fwrite(fd, mklend(recording_date,2), 'uint8' );
nb = nb + fwrite(fd, trial_num, 'uint8' );
nb = nb + fwrite(fd, size(F,2), 'uint8' );
nb = nb + fwrite(fd, mklend(Ts,2), 'uint8' );
nb = nb + fwrite(fd, mklend(post_triglen,4), 'uint8' );
nb = nb + fwrite(fd, notes, 'char' );
fprintf( 'Header written in %d bytes\n', nb );

% Actual data
% Make F into byte stream (single column, little endian)
F = reshape(F', size(F,1)*size(F,2), 1);
%F_le = zeros(length(F)*2, 1);
%for k = 1:length(F)
%    F_le(k*2-1:k*2) = mklend( F(k), 2 );
%end
%clear F; % Free up some heap
% We hope that the native machine is little-endian; otherwise, doing this
% by hand (a la splitting each sample into two separate bytes) requires an
% ungodly amount of time in Matlab.
nb = fwrite(fd, F, 'uint16' );
fprintf( 'Actual array data written in %d bytes.\n', nb*2 );

fclose(fd);


% Confer BatStack reference manual for format; specifically look in section
% on SD card/ flash memory header specs.
function rec_date = gendate( rec_date_str )
try
    rec_date_v = datevec( rec_date_str );
catch
    error( 'Unrecognized date string format: %s', rec_date_str );
end
rec_date = bitand(rec_date_v(3), hex2dec('1F')); % day
rec_date = bitor(rec_date, bitshift(bitand(rec_date_v(2), hex2dec('0F')), 5)); % month
rec_date = bitor(rec_date, bitshift(bitand(rec_date_v(1)-1970, hex2dec('7F')), 9)); % year


% Break val into byte array (i.e. column vector) of length val_len with little-endian ordering.
% Used in combination with fwrite(..., 'uint8') allows decent control over
% file manipulation at the byte-level (at least, decent given Matlab).
function byte_arr = mklend( val, val_len )
byte_arr = zeros(val_len,1);
for k = 1:val_len
    byte_arr(k) = bitand(val,255);
    val = bitshift(val,-8);
end
