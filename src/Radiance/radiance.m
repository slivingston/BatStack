function varargout = radiance(varargin)
% RADIANCE M-file for radiance.fig
%      RADIANCE, by itself, creates a new RADIANCE or raises the existing
%      singleton*.
%
%      H = RADIANCE returns the handle to a new RADIANCE or the handle to
%      the existing singleton*.
%
%      RADIANCE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RADIANCE.M with the given input arguments.
%
%      RADIANCE('Property','Value',...) creates a new RADIANCE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before radiance_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to radiance_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help radiance

% Last Modified by GUIDE v2.5 18-Mar-2011 14:58:12

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @radiance_OpeningFcn, ...
                   'gui_OutputFcn',  @radiance_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before radiance is made visible.
function radiance_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to radiance (see VARARGIN)

% Choose default command line output for radiance
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% Radiance-related init
global RADIANCE_GLOBAL;
RADIANCE_GLOBAL.array_filename = '';
RADIANCE_GLOBAL.d3_filename = '';
RADIANCE_GLOBAL.wamike_filename = '';
RADIANCE_GLOBAL.wagaincal_filename = '';
RADIANCE_GLOBAL.timestamp = '';
RADIANCE_GLOBAL.trial_num = nan;
RADIANCE_GLOBAL.bat_ID = '';
RADIANCE_GLOBAL.num_vocs = 0;
RADIANCE_GLOBAL.num_mics = 0;
RADIANCE_GLOBAL.T_start = [];
RADIANCE_GLOBAL.F_start = [];
RADIANCE_GLOBAL.T_stop = [];
RADIANCE_GLOBAL.F_stop = [];
RADIANCE_GLOBAL.temp = 22; % deg C
RADIANCE_GLOBAL.rel_humid = 50; % percent relative humidity
RADIANCE_GLOBAL.spd_sound = 343; % m/s (note that this is related to temperature and RH).

% ...and now mostly fields internal to this Radiance session
RADIANCE_GLOBAL.handles = handles; % It is easier to deal with if we carry a copy around in RADIANCE_GLOBAL.

if ispref('radiance','def_dir') && ...
    exist(getpref('radiance','def_dir'),'dir')
  RADIANCE_GLOBAL.def_dir=getpref('radiance','def_dir');
else
  RADIANCE_GLOBAL.def_dir='.';
end

RADIANCE_GLOBAL.buffer_len = 10240;
RADIANCE_GLOBAL.current_time = nan; % no trial loaded yet
RADIANCE_GLOBAL.current_chan_group = 1; % default to first mic group, i.e. channels 1 through 16.
RADIANCE_GLOBAL.plot_type = 0; % 0 --> time waveform
                               % 1 --> spectrogram
                               % 2 --> FFT magnitude plot
RADIANCE_GLOBAL.detail_chan = nan; % no channel selected yet for detail view
RADIANCE_GLOBAL.detail_stime = nan;
RADIANCE_GLOBAL.detail_twin = .050; % s, time window width
RADIANCE_GLOBAL.current_popped_chan = nan;
RADIANCE_GLOBAL.current_voc = 1;
RADIANCE_GLOBAL.beam_lo_freq = 28e3; % Hz
RADIANCE_GLOBAL.beam_hi_freq = 42e3; % Hz
RADIANCE_GLOBAL.last_saved_filename = '';
RADIANCE_GLOBAL.detail_chan_time_lock = 0; % Regarding forcing detailed channel view to match corresponding channel in signal grid (i.e. its "local time").
RADIANCE_GLOBAL.spect_min = -100;
RADIANCE_GLOBAL.spect_max = -20;
RADIANCE_GLOBAL.spect_winsize = 128;
RADIANCE_GLOBAL.spect_noverlap = 120;
RADIANCE_GLOBAL.spect_nfft = 256;

% UIWAIT makes radiance wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = radiance_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --------------------------------------------------------------------
function Untitled_1_Callback(hObject, eventdata, handles)
% hObject    handle to Untitled_1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function Untitled_2_Callback(hObject, eventdata, handles)
% hObject    handle to Untitled_2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function new_trial_request_Callback(hObject, eventdata, handles)
% hObject    handle to new_trial_request (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Confirmation dialog
ButtonName=questdlg( 'Start new trial?  Note that any unsaved work will be lost.', ...
                     'New Trial Confirmation', 'Yes', 'No', 'No' );
if ~strcmpi(ButtonName,'Yes')
    return
end

global RADIANCE_GLOBAL;

[array_filename, pathname] = uigetfile( '*.bin', 'Select raw array data file', RADIANCE_GLOBAL.def_dir );
if isequal(array_filename,0)
    return % User hit Cancel button.
else
    array_filename = [pathname array_filename];
end
[d3_filename, pathname] = uigetfile( '*_d3.mat', 'Select d3 analysed file', RADIANCE_GLOBAL.def_dir );
if isequal(d3_filename,0)
    return % User hit Cancel button.
else
    d3_filename = [pathname d3_filename];
end
[wamike_filename, pathname] = uigetfile( '*.wamike.txt', 'Select microphone position calibration', RADIANCE_GLOBAL.def_dir );
if isequal(wamike_filename,0)
    return % User hit Cancel button.
else
    wamike_filename = [pathname wamike_filename];
end
[wagaincal_filename, pathname] = uigetfile( '*.wagaincal.mat', 'Select gain calibration', RADIANCE_GLOBAL.def_dir );
if isequal(wagaincal_filename,0)
    return % User hit Cancel button.
else
    wagaincal_filename = [pathname wagaincal_filename];
end

% Now attempt to open them (again, no commitments to RADIANCE_GLOBAL until
% we are sure everything is legit.
fprintf( 'Reading array data file... ' );
[F,t,Ts,params] = loadafile( array_filename );
if isempty(F)
    fprintf( 'FAIL!\n' );
    return
else
    fprintf( 'Done.\n' );
end

fprintf( 'Reading d3-processed file... ' );
try
    d3f = load('-MAT',d3_filename);
    if ~isfield( d3f, 'd3_analysed' )
        fprintf('FAIL!\n');
        return
    end
    fprintf( 'Done.\n' );
catch
    fprintf( 'FAIL!\n' );
    return
end

fprintf( 'Reading mike position file... ' );
try
    mike_pos = load('-ASCII', wamike_filename );
    if size(mike_pos,2) ~= 3
        fprintf('FAIL!\n');
        return
    end
    fprintf( 'Done.\n' );
catch
    fprintf( 'FAIL!\n' );
    return
end

fprintf( 'Reading gain calibration file... ');
try
    gf = load('-MAT', wagaincal_filename );
    if ~isfield(gf, 'G' )
        fprintf('FAIL!\n');
        return
    end
    fprintf('Done.\n');
catch
    fprintf( 'FAIL!\n' );
    return
end

% One last sanity check: compare number of channels listed in params with
% number of rows given in mike position calibration file.
if isfield(params, 'num_channels') && params.num_channels ~= size(mike_pos,1)
    fprintf( 'Error: number of channels listed in array data file differs from\nthat given in position calibration file.\n' );
    return
end

% Commit to filenames
RADIANCE_GLOBAL.array_filename = array_filename;
RADIANCE_GLOBAL.d3_filename = d3_filename;
RADIANCE_GLOBAL.wamike_filename = wamike_filename;
RADIANCE_GLOBAL.wagaincal_filename = wagaincal_filename;

% Clear whatever was there before
RADIANCE_GLOBAL.num_vocs = 1;
RADIANCE_GLOBAL.bat_ID = '';
RADIANCE_GLOBAL.num_mics = size(mike_pos,1);
RADIANCE_GLOBAL.T_start = nan(RADIANCE_GLOBAL.num_mics,1);
RADIANCE_GLOBAL.F_start = RADIANCE_GLOBAL.T_start;
RADIANCE_GLOBAL.T_stop = RADIANCE_GLOBAL.T_start;
RADIANCE_GLOBAL.F_stop = RADIANCE_GLOBAL.T_start;
RADIANCE_GLOBAL.mike_pos = mike_pos;
RADIANCE_GLOBAL.bat = d3f.d3_analysed.object(1).video; % Assuming bat trajectory is that of first object.
RADIANCE_GLOBAL.vid_fps = d3f.d3_analysed.fvideo;
RADIANCE_GLOBAL.vid_start_frame = d3f.d3_analysed.startframe;
RADIANCE_GLOBAL.G = gf.G;
if isfield(gf,'freq_divs')
    RADIANCE_GLOBAL.freq_divs = gf.freq_divs;
end

if isfield(params, 'recording_date')
    RADIANCE_GLOBAL.timestamp = params.recording_date;
else
    RADIANCE_GLOBAL.timestamp = '';
end

if isfield(params, 'trial_number')
    RADIANCE_GLOBAL.trial_num = params.trial_number;
end

if isfield(params, 'sample_period')
    RADIANCE_GLOBAL.samp_period = params.sample_period;
else
    RADIANCE_GLOBAL.samp_period = Ts;
end

% And finally, the raw array data itself
RADIANCE_GLOBAL.F = F;
RADIANCE_GLOBAL.t = t;

% Environmental parameters
RADIANCE_GLOBAL.temp = 22; % deg C
RADIANCE_GLOBAL.rel_humid = 50; % percent relative humidity
RADIANCE_GLOBAL.spd_sound = 343; % m/s (note that this is related to temperature and RH).

% Adjust several internal GUI parameters accordingly
RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.vid_start_frame/RADIANCE_GLOBAL.vid_fps;
if RADIANCE_GLOBAL.current_time < RADIANCE_GLOBAL.t(1)
    RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.t(1); % Play it safe.
end
RADIANCE_GLOBAL.local_times = bat2arrtime( RADIANCE_GLOBAL.current_time ); % Reduces computation time later
RADIANCE_GLOBAL.plot_type = 0; % return to time waveform
RADIANCE_GLOBAL.detail_chan = 1;
RADIANCE_GLOBAL.detail_stime = RADIANCE_GLOBAL.local_times(RADIANCE_GLOBAL.detail_chan);
RADIANCE_GLOBAL.detail_twin = .050; % in seconds
RADIANCE_GLOBAL.current_chan_group = 1;
RADIANCE_GLOBAL.current_popped_chan = nan;
RADIANCE_GLOBAL.current_voc = 1;
RADIANCE_GLOBAL.beam_lo_freq = 28e3; % Hz
RADIANCE_GLOBAL.beam_hi_freq = 42e3; % Hz
RADIANCE_GLOBAL.detail_chan_time_lock = 0;
RADIANCE_GLOBAL.spect_min = -100;
RADIANCE_GLOBAL.spect_max = -20;
RADIANCE_GLOBAL.spect_winsize = 128;
RADIANCE_GLOBAL.spect_noverlap = 120;
RADIANCE_GLOBAL.spect_nfft = 256;

% Refresh relevant GUI widgets
update_button_grid(1);
set(RADIANCE_GLOBAL.handles.view_mode_select, 'Value', RADIANCE_GLOBAL.plot_type+1);
set(RADIANCE_GLOBAL.handles.time_box, 'String', num2str( RADIANCE_GLOBAL.current_time*1e3 ));
set(RADIANCE_GLOBAL.handles.vidframe_box, 'String', num2str( floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) ));
set(RADIANCE_GLOBAL.handles.t_window_size_box,'String', sprintf( '%.2f', RADIANCE_GLOBAL.buffer_len * RADIANCE_GLOBAL.samp_period*1e3 ) );
set(RADIANCE_GLOBAL.handles.current_voc_box,'String',num2str( RADIANCE_GLOBAL.current_voc ) );
set(RADIANCE_GLOBAL.handles.low_freq_box,'String', sprintf('%.3f',RADIANCE_GLOBAL.beam_lo_freq/1e3) );
set(RADIANCE_GLOBAL.handles.high_freq_box,'String', sprintf('%.3f',RADIANCE_GLOBAL.beam_hi_freq/1e3) );
set(RADIANCE_GLOBAL.handles.spectrogram_min_box,'String', sprintf('%.3f',RADIANCE_GLOBAL.spect_min) );
set(RADIANCE_GLOBAL.handles.spectrogram_max_box,'String', sprintf('%.3f',RADIANCE_GLOBAL.spect_max) );

% Session info box
dmarks = strfind( RADIANCE_GLOBAL.array_filename, '\' ); % Assuming we are on Windows >_<
if isempty(dmarks)
    dmarks = [0];
end
set(RADIANCE_GLOBAL.handles.array_data_filename_box, 'String', RADIANCE_GLOBAL.array_filename(dmarks(end)+1:end) );
set(RADIANCE_GLOBAL.handles.array_data_filename_box, 'TooltipString', RADIANCE_GLOBAL.array_filename );
dmarks = strfind( RADIANCE_GLOBAL.d3_filename, '\' );
if isempty(dmarks)
    dmarks = [0];
end
set(RADIANCE_GLOBAL.handles.d3_analysed_filename_box, 'String', RADIANCE_GLOBAL.d3_filename(dmarks(end)+1:end) );
set(RADIANCE_GLOBAL.handles.d3_analysed_filename_box, 'TooltipString', RADIANCE_GLOBAL.d3_filename );
dmarks = strfind( RADIANCE_GLOBAL.wamike_filename, '\' );
if isempty(dmarks)
    dmarks = [0];
end
set(RADIANCE_GLOBAL.handles.wamike_filename_box, 'String', RADIANCE_GLOBAL.wamike_filename(dmarks(end)+1:end) );
set(RADIANCE_GLOBAL.handles.wamike_filename_box, 'TooltipString', RADIANCE_GLOBAL.wamike_filename );
dmarks = strfind( RADIANCE_GLOBAL.wagaincal_filename, '\' );
if isempty(dmarks)
    dmarks = [0];
end
set(RADIANCE_GLOBAL.handles.wagaincal_filename_box, 'String', RADIANCE_GLOBAL.wagaincal_filename(dmarks(end)+1:end) );
set(RADIANCE_GLOBAL.handles.wagaincal_filename_box, 'TooltipString', RADIANCE_GLOBAL.wagaincal_filename );

% Build detail channel view menu
ch_list = cell(RADIANCE_GLOBAL.num_mics,1);
for k = 1:RADIANCE_GLOBAL.num_mics
    ch_list{k} = num2str(k);
end
set( RADIANCE_GLOBAL.handles.detail_channel_select, 'String', ch_list );
set( RADIANCE_GLOBAL.handles.detail_channel_select, 'Value', RADIANCE_GLOBAL.detail_chan );
set( RADIANCE_GLOBAL.handles.detail_channel_tstart_box, 'String', num2str( RADIANCE_GLOBAL.detail_stime*1e3 ) );
set( RADIANCE_GLOBAL.handles.detail_channel_tdur_box, 'String', num2str( RADIANCE_GLOBAL.detail_twin*1e3 ) );

% Build channel group menu
num_ch_groups = ceil(RADIANCE_GLOBAL.num_mics/16);
ch_grp_str = cell(num_ch_groups,1);
for k = 1:num_ch_groups
    if RADIANCE_GLOBAL.num_mics-((k-1)*16+1) < 15
        ch_grp_str{k} = sprintf( '%d-%d', (k-1)*16+1, RADIANCE_GLOBAL.num_mics );
    else
        ch_grp_str{k} = sprintf( '%d-%d', (k-1)*16+1, k*16 );
    end
end
set(RADIANCE_GLOBAL.handles.channel_group_select, 'String', ch_grp_str );

if ~isfield(RADIANCE_GLOBAL.handles,'grid_axes')
    init_signal_grid;
end
update_plots; % Refresh all plots (signal grid and detailed channel view).


% --------------------------------------------------------------------
function credits_box_Callback(hObject, eventdata, handles)
% hObject    handle to credits_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
msgbox(sprintf('Scott Livingston  <slivingston@caltech.edu>\nAuditory Neuroethology Lab (or the "Batlab")\nU. Maryland, College Park\n(c) 2009-2011\n\nwith contributions from:\nBen Falk'),'Radiance, software for wideband microphone array analysis','modal');


% --------------------------------------------------------------------
function open_trial_request_Callback(hObject, eventdata, handles)

% Confirmation dialog
ButtonName=questdlg( 'Open (existing) trial analysis?  Note that any unsaved work will be lost.', ...
                     'Open Trial Confirmation', 'Yes', 'No', 'No' );
if ~strcmpi(ButtonName,'Yes')
    return
end

global RADIANCE_GLOBAL;

[fname, pathname] = uigetfile( '*_rad.mat', 'Select a Radiance analysis file.', RADIANCE_GLOBAL.def_dir );
if isequal(fname,0)
    return % User hit Cancel button; abort silently.
end

try
    rf = load('-MAT',[pathname fname]);
catch
    fprintf( 'Error occurred while attempting to open %s\n', [pathname fname] );
    return % error; do nothing.
end
if ~isfield(rf,'radiance_analysed')
    fprintf( 'File contents are invalid; failed to load %s\n', [pathname fname] );
    return % error
end

fprintf( 'Loaded %s; attempting to start an analysis session...\n', [pathname fname] );

% Before trying much, we need to confirm availability of array data file,
% d3_analysed file, and microphone position and gain calibration.
D = dir(rf.radiance_analysed.data_file);
if isempty(D)
    [array_filename, pathname] = uigetfile( '*.bin', 'Failed to auto-load; Select raw array data file', RADIANCE_GLOBAL.def_dir );
    if isequal(array_filename,0)
        return % User hit Cancel button.
    else
        rf.radiance_analysed.data_file = [pathname array_filename];
    end
end
fprintf( 'Reading array data file... ' );
[F,t,Ts,params] = loadafile( rf.radiance_analysed.data_file );
if isempty(F)
    fprintf( 'FAIL!\n' );
    return
else
    fprintf( 'Done.\n' );
end

D = dir(rf.radiance_analysed.d3_file);
if isempty(D)
    [d3_filename, pathname] = uigetfile( '*_d3.mat', 'Failed to auto-load; Select d3 analysed file', RADIANCE_GLOBAL.def_dir );
    if isequal(d3_filename,0)
        return % User hit Cancel button.
    else
        rf.radiance_analysed.d3_file = [pathname d3_filename];
    end
end
fprintf( 'Reading d3-processed file... ' );
try
    d3f = load('-MAT',rf.radiance_analysed.d3_file);
    if ~isfield( d3f, 'd3_analysed' )
        fprintf('FAIL!\n');
        return
    end
    fprintf( 'Done.\n' );
catch
    fprintf( 'FAIL!\n' );
    return
end

D = dir(rf.radiance_analysed.wamike_file);
if isempty(D)
    [wamike_filename, pathname] = uigetfile( '*.wamike.txt', 'Failed to auto-load; Select microphone position calibration', RADIANCE_GLOBAL.def_dir );
    if isequal(wamike_filename,0)
        return % User hit Cancel button.
    else
        rf.radiance_analysed.wamike_file = [pathname wamike_filename];
    end
end
fprintf( 'Reading mike position file... ' );
try
    mike_pos = load('-ASCII', rf.radiance_analysed.wamike_file );
    if size(mike_pos,2) ~= 3
        fprintf('FAIL!\n');
        return
    end
    fprintf( 'Done.\n' );
catch
    fprintf( 'FAIL!\n' );
    return
end

D = dir(rf.radiance_analysed.wagaincal_file);
if isempty(D)
    [wagaincal_filename, pathname] = uigetfile( '*.wagaincal.mat', 'Failed to auto-load; Select gain calibration', RADIANCE_GLOBAL.def_dir );
    if isequal(wagaincal_filename,0)
        return % User hit Cancel button.
    else
        rf.radiance_analysed.wagaincal_file = [pathname wagaincal_filename];
    end
end
fprintf( 'Reading gain calibration file... ');
try
    gf = load('-MAT', rf.radiance_analysed.wagaincal_file );
    if ~isfield(gf, 'G' )
        fprintf('FAIL!\n');
        return
    end
    fprintf('Done.\n');
catch
    fprintf( 'FAIL!\n' );
    return
end

% Commit to filenames
RADIANCE_GLOBAL.array_filename = rf.radiance_analysed.data_file;
RADIANCE_GLOBAL.d3_filename = rf.radiance_analysed.d3_file;
RADIANCE_GLOBAL.wamike_filename = rf.radiance_analysed.wamike_file;
RADIANCE_GLOBAL.wagaincal_filename = rf.radiance_analysed.wagaincal_file;

% Copy relevant fields from opened analysis file
RADIANCE_GLOBAL.timestamp = rf.radiance_analysed.timestamp;
RADIANCE_GLOBAL.bat_ID = rf.radiance_analysed.bat_ID;
RADIANCE_GLOBAL.owner = rf.radiance_analysed.owner;
RADIANCE_GLOBAL.num_vocs = rf.radiance_analysed.num_vocs;
RADIANCE_GLOBAL.num_mics = rf.radiance_analysed.num_mics;
RADIANCE_GLOBAL.T_start = rf.radiance_analysed.T_start;
RADIANCE_GLOBAL.F_start = rf.radiance_analysed.F_start;
RADIANCE_GLOBAL.T_stop = rf.radiance_analysed.T_stop;
RADIANCE_GLOBAL.F_stop = rf.radiance_analysed.F_stop;

% And stuff from data and calibration files
RADIANCE_GLOBAL.mike_pos = mike_pos;
RADIANCE_GLOBAL.bat = d3f.d3_analysed.object(1).video; % Assuming bat trajectory is that of first object.
RADIANCE_GLOBAL.vid_fps = d3f.d3_analysed.fvideo;
RADIANCE_GLOBAL.vid_start_frame = d3f.d3_analysed.startframe;
RADIANCE_GLOBAL.G = gf.G;
if isfield(gf,'freq_divs')
    RADIANCE_GLOBAL.freq_divs = gf.freq_divs;
end

if isfield(params, 'sample_period')
    RADIANCE_GLOBAL.samp_period = params.sample_period;
else
    RADIANCE_GLOBAL.samp_period = Ts;
end

% And finally, the raw array data itself
RADIANCE_GLOBAL.F = F;
RADIANCE_GLOBAL.t = t;

% Environmental parameters
RADIANCE_GLOBAL.temp = 22; % deg C
RADIANCE_GLOBAL.rel_humid = 50; % percent relative humidity
RADIANCE_GLOBAL.spd_sound = 343; % m/s (note that this is related to temperature and RH).

% Adjust several internal GUI parameters accordingly
RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.vid_start_frame/RADIANCE_GLOBAL.vid_fps;
if RADIANCE_GLOBAL.current_time < RADIANCE_GLOBAL.t(1)
    RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.t(1); % Play it safe.
end
RADIANCE_GLOBAL.local_times = bat2arrtime( RADIANCE_GLOBAL.current_time ); % Reduces computation time later
RADIANCE_GLOBAL.plot_type = 0; % return to time waveform
RADIANCE_GLOBAL.detail_chan = 1;
RADIANCE_GLOBAL.detail_stime = RADIANCE_GLOBAL.local_times(RADIANCE_GLOBAL.detail_chan);
RADIANCE_GLOBAL.detail_twin = .002; % in seconds
RADIANCE_GLOBAL.current_chan_group = 1;
RADIANCE_GLOBAL.current_popped_chan = nan;
RADIANCE_GLOBAL.current_voc = 1;
RADIANCE_GLOBAL.detail_chan_time_lock = 0;
RADIANCE_GLOBAL.spect_min = -100;
RADIANCE_GLOBAL.spect_max = -20;
RADIANCE_GLOBAL.spect_winsize = 128;
RADIANCE_GLOBAL.spect_noverlap = 120;
RADIANCE_GLOBAL.spect_nfft = 256;

% Refresh relevant GUI widgets
update_button_grid(1);
set(RADIANCE_GLOBAL.handles.view_mode_select, 'Value', RADIANCE_GLOBAL.plot_type+1);
set(RADIANCE_GLOBAL.handles.time_box, 'String', num2str( RADIANCE_GLOBAL.current_time*1e3 ));
set(RADIANCE_GLOBAL.handles.vidframe_box, 'String', num2str( floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) ));
set(RADIANCE_GLOBAL.handles.t_window_size_box,'String', sprintf( '%.2f', RADIANCE_GLOBAL.buffer_len * RADIANCE_GLOBAL.samp_period*1e3 ) );
set(RADIANCE_GLOBAL.handles.current_voc_box,'String',num2str( RADIANCE_GLOBAL.current_voc ) );
set(RADIANCE_GLOBAL.handles.spectrogram_min_box,'String', sprintf('%.3f',RADIANCE_GLOBAL.spect_min) );
set(RADIANCE_GLOBAL.handles.spectrogram_max_box,'String', sprintf('%.3f',RADIANCE_GLOBAL.spect_max) );

% Session info box
dmarks = strfind( RADIANCE_GLOBAL.array_filename, '\' ); % Assuming we are on Windows >_<
if isempty(dmarks)
    dmarks = [0];
end
set(RADIANCE_GLOBAL.handles.array_data_filename_box, 'String', RADIANCE_GLOBAL.array_filename(dmarks(end)+1:end) );
set(RADIANCE_GLOBAL.handles.array_data_filename_box, 'TooltipString', RADIANCE_GLOBAL.array_filename );
dmarks = strfind( RADIANCE_GLOBAL.d3_filename, '\' );
if isempty(dmarks)
    dmarks = [0];
end
set(RADIANCE_GLOBAL.handles.d3_analysed_filename_box, 'String', RADIANCE_GLOBAL.d3_filename(dmarks(end)+1:end) );
set(RADIANCE_GLOBAL.handles.d3_analysed_filename_box, 'TooltipString', RADIANCE_GLOBAL.d3_filename );
dmarks = strfind( RADIANCE_GLOBAL.wamike_filename, '\' );
if isempty(dmarks)
    dmarks = [0];
end
set(RADIANCE_GLOBAL.handles.wamike_filename_box, 'String', RADIANCE_GLOBAL.wamike_filename(dmarks(end)+1:end) );
set(RADIANCE_GLOBAL.handles.wamike_filename_box, 'TooltipString', RADIANCE_GLOBAL.wamike_filename );
dmarks = strfind( RADIANCE_GLOBAL.wagaincal_filename, '\' );
if isempty(dmarks)
    dmarks = [0];
end
set(RADIANCE_GLOBAL.handles.wagaincal_filename_box, 'String', RADIANCE_GLOBAL.wagaincal_filename(dmarks(end)+1:end) );
set(RADIANCE_GLOBAL.handles.wagaincal_filename_box, 'TooltipString', RADIANCE_GLOBAL.wagaincal_filename );

% Build detail channel view menu
ch_list = cell(RADIANCE_GLOBAL.num_mics,1);
for k = 1:RADIANCE_GLOBAL.num_mics
    ch_list{k} = num2str(k);
end
set( RADIANCE_GLOBAL.handles.detail_channel_select, 'String', ch_list );
set( RADIANCE_GLOBAL.handles.detail_channel_select, 'Value', RADIANCE_GLOBAL.detail_chan );
set( RADIANCE_GLOBAL.handles.detail_channel_tstart_box, 'String', num2str( RADIANCE_GLOBAL.detail_stime*1e3 ) );
set( RADIANCE_GLOBAL.handles.detail_channel_tdur_box, 'String', num2str( RADIANCE_GLOBAL.detail_twin*1e3 ) );

% Build channel group menu
num_ch_groups = ceil(RADIANCE_GLOBAL.num_mics/16);
ch_grp_str = cell(num_ch_groups,1);
for k = 1:num_ch_groups
    if RADIANCE_GLOBAL.num_mics-((k-1)*16+1) < 15
        ch_grp_str{k} = sprintf( '%d-%d', (k-1)*16+1, RADIANCE_GLOBAL.num_mics );
    else
        ch_grp_str{k} = sprintf( '%d-%d', (k-1)*16+1, k*16 );
    end
end
set(RADIANCE_GLOBAL.handles.channel_group_select, 'String', ch_grp_str );

if ~isfield(RADIANCE_GLOBAL.handles,'grid_axes')
    init_signal_grid;
end
update_plots; % Refresh all plots (signal grid and detailed channel view).
fprintf( 'Done.\n' );


% --------------------------------------------------------------------
function save_trial_as_Callback(hObject, eventdata, handles)
% hObject    handle to save_trial_as (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global RADIANCE_GLOBAL

% First verify that an analysis session is even active
if RADIANCE_GLOBAL.num_mics == 0 && isempty(RADIANCE_GLOBAL.array_filename)
    fig = msgbox('No active analysis session to save.');
    uiwait(fig);
    return
end

if ~isempty(RADIANCE_GLOBAL.last_saved_filename)
    [fname pathname] = uiputfile( '*_rad.mat', 'Save results in a Radiance analysis file.', RADIANCE_GLOBAL.last_saved_filename );
else
    [fname pathname] = uiputfile( '*_rad.mat', 'Save results in a Radiance analysis file.', RADIANCE_GLOBAL.def_dir );
end
if isequal(fname,0)
    return % User hit cancel, abort silently
end
fname = [pathname fname];
RADIANCE_GLOBAL.last_saved_filename = fname;

if save_radmat_file( fname ) == -1
    fprintf( 'Error: occurred while attempting to save Radiance results file %s\n', fname );
end


% --------------------------------------------------------------------
function last_flowers_Callback(hObject, eventdata, handles)
% hObject    handle to last_flowers (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%fig = msgbox(sprintf('No need for fire and brimstone,\nHell is other people!'),'no exit','modal');
%uiwait(fig); % Wait for user to acknowledge Sarte's poem.
% Confirmation dialog
ButtonName=questdlg( 'Are you sure?  Note that any unsaved work will be lost.', ...
                     'Exit Confirmation', 'Yes', 'No', 'No' );
if ~strcmpi(ButtonName,'Yes')
    return
end
clear global RADIANCE_GLOBAL;
close(gcf);  % and then close the application.


% --------------------------------------------------------------------
function set_def_paths_Callback(hObject, eventdata, handles)
% hObject    handle to set_def_paths (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
msg = 'Select default directory for finding stuff.';
fprintf( '\n%s\n', msg );

%grabbing any previous stored def dir
if ispref('radiance','def_dir') && ...
    exist(getpref('radiance','def_dir'),'dir')
  STARTDIR=getpref('radiance','def_dir');
else
  STARTDIR='.';
end

req_path = uigetdir(STARTDIR, msg );

if isequal(req_path,0)
    return % User hit Cancel button; ignore.
end
RADIANCE_GLOBAL.def_dir = req_path;
RADIANCE_GLOBAL.last_saved_dir = RADIANCE_GLOBAL.def_dir;

%storing the def dir as a pref
setpref('radiance','def_dir',req_path);


% --- Executes on button press in cell11.
function cell11_Callback(hObject, eventdata, handles)
% hObject    handle to cell11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 1, 1 );

% --- Executes on button press in cell12.
function cell12_Callback(hObject, eventdata, handles)
% hObject    handle to cell12 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 1, 2 );

% --- Executes on button press in cell13.
function cell13_Callback(hObject, eventdata, handles)
% hObject    handle to cell13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 1, 3 );

% --- Executes on button press in cell14.
function cell14_Callback(hObject, eventdata, handles)
% hObject    handle to cell14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 1, 4 );

% --- Executes on button press in cell21.
function cell21_Callback(hObject, eventdata, handles)
% hObject    handle to cell21 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 2, 1 );

% --- Executes on button press in cell22.
function cell22_Callback(hObject, eventdata, handles)
% hObject    handle to cell22 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 2, 2 );

% --- Executes on button press in cell23.
function cell23_Callback(hObject, eventdata, handles)
% hObject    handle to cell23 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 2, 3 );

% --- Executes on button press in cell24.
function cell24_Callback(hObject, eventdata, handles)
% hObject    handle to cell24 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 2, 4 );

% --- Executes on button press in cell31.
function cell31_Callback(hObject, eventdata, handles)
% hObject    handle to cell31 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 3, 1 );

% --- Executes on button press in cell32.
function cell32_Callback(hObject, eventdata, handles)
% hObject    handle to cell32 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 3, 2 );

% --- Executes on button press in cell33.
function cell33_Callback(hObject, eventdata, handles)
% hObject    handle to cell33 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 3, 3 );

% --- Executes on button press in cell34.
function cell34_Callback(hObject, eventdata, handles)
% hObject    handle to cell34 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 3, 4 );

% --- Executes on button press in cell41.
function cell41_Callback(hObject, eventdata, handles)
% hObject    handle to cell41 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 4, 1 );

% --- Executes on button press in cell42.
function cell42_Callback(hObject, eventdata, handles)
% hObject    handle to cell42 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 4, 2 );

% --- Executes on button press in cell43.
function cell43_Callback(hObject, eventdata, handles)
% hObject    handle to cell43 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 4, 3 );

% --- Executes on button press in cell44.
function cell44_Callback(hObject, eventdata, handles)
% hObject    handle to cell44 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
popout_gridcell( 4, 4 );

% --- Executes on selection change in channel_group_select.
function channel_group_select_Callback(hObject, eventdata, handles)
% hObject    handle to channel_group_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
RADIANCE_GLOBAL.current_chan_group = floor(get(hObject,'Value'));
update_plots;


% --- Executes during object creation, after setting all properties.
function channel_group_select_CreateFcn(hObject, eventdata, handles)
% hObject    handle to channel_group_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in view_mode_select.
function view_mode_select_Callback(hObject, eventdata, handles)
% hObject    handle to view_mode_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns view_mode_select contents as cell array
%        contents{get(hObject,'Value')} returns selected item from view_mode_select
global RADIANCE_GLOBAL;
RADIANCE_GLOBAL.plot_type = floor(get(hObject,'Value'))-1;
update_plots;


% --- Executes during object creation, after setting all properties.
function view_mode_select_CreateFcn(hObject, eventdata, handles)
% hObject    handle to view_mode_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function time_box_Callback(hObject, eventdata, handles)
% hObject    handle to time_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
requested_time = str2num(get(hObject,'String'));
if isempty(requested_time)
    set(RADIANCE_GLOBAL.handles.time_box,'String', RADIANCE_GLOBAL.current_time*1e3 );
    return % Given invalid time; ignore.
end
requested_time = requested_time*1e-3; % convert from ms to s.
last_bat_time = (length(RADIANCE_GLOBAL.bat)-1+RADIANCE_GLOBAL.vid_start_frame)/RADIANCE_GLOBAL.vid_fps;
first_bat_time = RADIANCE_GLOBAL.vid_start_frame/RADIANCE_GLOBAL.vid_fps;
if requested_time < RADIANCE_GLOBAL.t(1) || requested_time < first_bat_time
    if RADIANCE_GLOBAL.t(1) > first_bat_time
        RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.t(1);
    else
        RADIANCE_GLOBAL.current_time = first_bat_time;
    end
    set(RADIANCE_GLOBAL.handles.time_box,'String', RADIANCE_GLOBAL.current_time*1e3 );
elseif requested_time > RADIANCE_GLOBAL.t(end) || requested_time > last_bat_time
    if RADIANCE_GLOBAL.t(end) < last_bat_time
        RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.t(end)-(RADIANCE_GLOBAL.buffer_len-1)*RADIANCE_GLOBAL.samp_period;
    else
        RADIANCE_GLOBAL.current_time = last_bat_time-(RADIANCE_GLOBAL.buffer_len-1)*RADIANCE_GLOBAL.samp_period/2;
    end
	set(RADIANCE_GLOBAL.handles.time_box,'String', RADIANCE_GLOBAL.current_time*1e3 );
else
    RADIANCE_GLOBAL.current_time = requested_time;
end
RADIANCE_GLOBAL.local_times = bat2arrtime( RADIANCE_GLOBAL.current_time );
set(RADIANCE_GLOBAL.handles.vidframe_box, 'String', num2str( floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) ));
update_plots;


% --- Executes during object creation, after setting all properties.
function time_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to time_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function vidframe_box_Callback(hObject, eventdata, handles)
global RADIANCE_GLOBAL;
set(RADIANCE_GLOBAL.handles.vidframe_box, 'String', num2str( floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) ));


% --- Executes during object creation, after setting all properties.
function vidframe_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to vidframe_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function buf_size_box_Callback(hObject, eventdata, handles)
% hObject    handle to buf_size_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
requested_len = str2num( get(hObject,'String') );
if isempty(requested_len)
    set(RADIANCE_GLOBAL.handles.buf_size_box,'String', num2str(RADIANCE_GLOBAL.buffer_len) );
    return % Invalid length; ignore.
end
requested_len = round(requested_len); % Force to be integral.
if requested_len < 1
    RADIANCE_GLOBAL.buffer_len = 1;
elseif requested_len > size(RADIANCE_GLOBAL.F,1)
    RADIANCE_GLOBAL.buffer_len = size(RADIANCE_GLOBAL.F,1);
else
    RADIANCE_GLOBAL.buffer_len = requested_len;
end
set(RADIANCE_GLOBAL.handles.t_window_size_box,'String', sprintf( '%.2f', RADIANCE_GLOBAL.buffer_len * RADIANCE_GLOBAL.samp_period*1e3 ) );
update_plots;


% --- Executes during object creation, after setting all properties.
function buf_size_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to buf_size_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in detail_channel_select.
function detail_channel_select_Callback(hObject, eventdata, handles)
% hObject    handle to detail_channel_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
requested_chan = get(hObject,'Value');
if isempty(requested_chan)
    return % Given bad value; ignore.
end
RADIANCE_GLOBAL.detail_chan = floor(requested_chan);
update_plots;


% --- Executes during object creation, after setting all properties.
function detail_channel_select_CreateFcn(hObject, eventdata, handles)
% hObject    handle to detail_channel_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function detail_channel_tstart_box_Callback(hObject, eventdata, handles)
% hObject    handle to detail_channel_tstart_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of detail_channel_tstart_box as text
%        str2double(get(hObject,'String')) returns contents of
%        detail_channel_tstart_box as a double
global RADIANCE_GLOBAL;
requested_time = str2num( get(hObject,'String') );
if isempty(requested_time)
    set(RADIANCE_GLOBAL.handles.detail_channel_tstart_box,'String', sprintf('%.2f',RADIANCE_GLOBAL.detail_stime*1e3) );
    return % Invalid time; ignore.
end
requested_time = requested_time*1e-3; % Convert from given ms units to seconds.
if requested_time < RADIANCE_GLOBAL.t(1)
    RADIANCE_GLOBAL.detail_stime = RADIANCE_GLOBAL.t(1);
elseif requested_time > RADIANCE_GLOBAL.t(end)
    RADIANCE_GLOBAL.detail_stime = RADIANCE_GLOBAL.t(end)-2*RADIANCE_GLOBAL.twin+RADIANCE_GLOBAL.samp_period;
else
    RADIANCE_GLOBAL.detail_stime = requested_time;
end
set(RADIANCE_GLOBAL.handles.detail_channel_tstart_box,'String', sprintf('%.2f',RADIANCE_GLOBAL.detail_stime*1e3) );
update_plots;


% --- Executes during object creation, after setting all properties.
function detail_channel_tstart_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to detail_channel_tstart_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function detail_channel_tdur_box_Callback(hObject, eventdata, handles)
% hObject    handle to detail_channel_tdur_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
requested_win = str2num( get(hObject,'String') );
if isempty(requested_win) || requested_win <= 0
    set(RADIANCE_GLOBAL.handles.detail_channel_tdur_box,'String', sprintf('%.2f', RADIANCE_GLOBAL.detail_twin*1e3 ) );
    return
end
requested_win = requested_win*1e-3; % Convert from ms to s.
RADIANCE_GLOBAL.detail_twin = requested_win;
update_plots;


% --- Executes during object creation, after setting all properties.
function detail_channel_tdur_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to detail_channel_tdur_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in popout_scene_axes.
function popout_scene_axes_Callback(hObject, eventdata, handles)
% hObject    handle to popout_scene_axes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
fig_h = figure;
ax_h = axes;
current_rel_frame = floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) - RADIANCE_GLOBAL.vid_start_frame + 1;
plot3( ax_h, ...
       RADIANCE_GLOBAL.bat(:,1), RADIANCE_GLOBAL.bat(:,2), RADIANCE_GLOBAL.bat(:,3), 'b-', ...
       RADIANCE_GLOBAL.bat(current_rel_frame,1), RADIANCE_GLOBAL.bat(current_rel_frame,2), RADIANCE_GLOBAL.bat(current_rel_frame,3), 'mo', ...
       RADIANCE_GLOBAL.mike_pos(:,1), RADIANCE_GLOBAL.mike_pos(:,2), RADIANCE_GLOBAL.mike_pos(:,3), 'r*' );
axis( ax_h, 'equal' );
grid( ax_h, 'on' );


% --------------------------------------------------------------------
function Untitled_3_Callback(hObject, eventdata, handles)
% hObject    handle to Untitled_3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function clear_marking_request_Callback(hObject, eventdata, handles)
% hObject    handle to clear_marking_request (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in goto_start_button.
function goto_start_button_Callback(hObject, eventdata, handles)
% hObject    handle to goto_start_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
first_bat_time = RADIANCE_GLOBAL.vid_start_frame/RADIANCE_GLOBAL.vid_fps;
if RADIANCE_GLOBAL.t(1) > first_bat_time
    RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.t(1);
else
    RADIANCE_GLOBAL.current_time = first_bat_time;
end
RADIANCE_GLOBAL.local_times = bat2arrtime( RADIANCE_GLOBAL.current_time );
set(RADIANCE_GLOBAL.handles.time_box, 'String', sprintf( '%.2f', RADIANCE_GLOBAL.current_time*1e3 ));
set(RADIANCE_GLOBAL.handles.vidframe_box, 'String', num2str( floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) ));
update_plots;


% --- Executes on button press in back_button.
function back_button_Callback(hObject, eventdata, handles)
% hObject    handle to back_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
first_bat_time = RADIANCE_GLOBAL.vid_start_frame/RADIANCE_GLOBAL.vid_fps;
new_time = RADIANCE_GLOBAL.current_time - (RADIANCE_GLOBAL.buffer_len-1)*RADIANCE_GLOBAL.samp_period/2;
if new_time < RADIANCE_GLOBAL.t(1) || new_time < first_bat_time
    if RADIANCE_GLOBAL.t(1) > first_bat_time
        RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.t(1);
    else
        RADIANCE_GLOBAL.current_time = first_bat_time;
    end
else
    RADIANCE_GLOBAL.current_time = new_time;
end
RADIANCE_GLOBAL.local_times = bat2arrtime( RADIANCE_GLOBAL.current_time );
set(RADIANCE_GLOBAL.handles.time_box, 'String', sprintf( '%.2f', RADIANCE_GLOBAL.current_time*1e3 ));
set(RADIANCE_GLOBAL.handles.vidframe_box, 'String', num2str( floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) ));
update_plots;


% --- Executes on button press in forward_button.
function forward_button_Callback(hObject, eventdata, handles)
% hObject    handle to forward_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
last_bat_time = (length(RADIANCE_GLOBAL.bat)-1+RADIANCE_GLOBAL.vid_start_frame)/RADIANCE_GLOBAL.vid_fps;
new_time = RADIANCE_GLOBAL.current_time + (RADIANCE_GLOBAL.buffer_len-1)*RADIANCE_GLOBAL.samp_period/2;
if new_time > RADIANCE_GLOBAL.t(end) || new_time > last_bat_time
    return % ignore request
end
%     if RADIANCE_GLOBAL.t(end) < last_bat_time
%         RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.t(end) - (RADIANCE_GLOBAL.buffer_len-1)*RADIANCE_GLOBAL.samp_period;
%     else
%         RADIANCE_GLOBAL.current_time = last_bat_time - (RADIANCE_GLOBAL.buffer_len-1)*RADIANCE_GLOBAL.samp_period;
%     end
% else
%     RADIANCE_GLOBAL.current_time = new_time;
% end
RADIANCE_GLOBAL.current_time = new_time;
RADIANCE_GLOBAL.local_times = bat2arrtime( RADIANCE_GLOBAL.current_time );
set(RADIANCE_GLOBAL.handles.time_box, 'String', sprintf( '%.2f', RADIANCE_GLOBAL.current_time*1e3 ));
set(RADIANCE_GLOBAL.handles.vidframe_box, 'String', num2str( floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) ));
update_plots;


% --- Executes on button press in goto_end_button.
function goto_end_button_Callback(hObject, eventdata, handles)
% hObject    handle to goto_end_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
last_bat_time = (length(RADIANCE_GLOBAL.bat)-1+RADIANCE_GLOBAL.vid_start_frame)/RADIANCE_GLOBAL.vid_fps;
if RADIANCE_GLOBAL.t(end) < last_bat_time
    RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.t(end) - (RADIANCE_GLOBAL.buffer_len-1)*RADIANCE_GLOBAL.samp_period/4;
else
    RADIANCE_GLOBAL.current_time = last_bat_time - (RADIANCE_GLOBAL.buffer_len-1)*RADIANCE_GLOBAL.samp_period/4;
end
RADIANCE_GLOBAL.local_times = bat2arrtime( RADIANCE_GLOBAL.current_time );
set(RADIANCE_GLOBAL.handles.time_box, 'String', sprintf( '%.2f', RADIANCE_GLOBAL.current_time*1e3 ));
set(RADIANCE_GLOBAL.handles.vidframe_box, 'String', num2str( floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) ));
update_plots;


function array_data_filename_box_Callback(hObject, eventdata, handles)
% hObject    handle to array_data_filename_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
dmarks = strfind( RADIANCE_GLOBAL.array_filename, '\' ); % Assuming we are on Windows >_<
if isempty(dmarks)
    dmarks = [0];
end
set(hObject, 'String', RADIANCE_GLOBAL.array_filename(dmarks(end)+1:end) );
set(hObject, 'TooltipString', RADIANCE_GLOBAL.array_filename );


% --- Executes during object creation, after setting all properties.
function array_data_filename_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to array_data_filename_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function d3_analysed_filename_box_Callback(hObject, eventdata, handles)
% hObject    handle to d3_analysed_filename_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
dmarks = strfind( RADIANCE_GLOBAL.d3_filename, '\' ); % Assuming we are on Windows >_<
if isempty(dmarks)
    dmarks = [0];
end
set(hObject, 'String', RADIANCE_GLOBAL.d3_filename(dmarks(end)+1:end) );
set(hObject, 'TooltipString', RADIANCE_GLOBAL.d3_filename );


% --- Executes during object creation, after setting all properties.
function d3_analysed_filename_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to d3_analysed_filename_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function wamike_filename_box_Callback(hObject, eventdata, handles)
% hObject    handle to wamike_filename_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
dmarks = strfind( RADIANCE_GLOBAL.wamike_filename, '\' ); % Assuming we are on Windows >_<
if isempty(dmarks)
    dmarks = [0];
end
set(hObject, 'String', RADIANCE_GLOBAL.wamike_filename(dmarks(end)+1:end) );
set(hObject, 'TooltipString', RADIANCE_GLOBAL.wamike_filename );


% --- Executes during object creation, after setting all properties.
function wamike_filename_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to wamike_filename_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function wagaincal_filename_box_Callback(hObject, eventdata, handles)
% hObject    handle to wagaincal_filename_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
dmarks = strfind( RADIANCE_GLOBAL.wagaincal_filename, '\' ); % Assuming we are on Windows >_<
if isempty(dmarks)
    dmarks = [0];
end
set(hObject, 'String', RADIANCE_GLOBAL.wagaincal_filename(dmarks(end)+1:end) );
set(hObject, 'TooltipString', RADIANCE_GLOBAL.wagaincal_filename );


% --- Executes during object creation, after setting all properties.
function wagaincal_filename_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to wagaincal_filename_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% Save current session to Radiance analysis results file of given name.
% Returns 0 on success, -1 on failure (in the Unix tradition).
function [error_code] = save_radmat_file( fname )
error_code = 0;
global RADIANCE_GLOBAL;
radiance_analysed = struct;
radiance_analysed.version = 1; % There is only one version, for now...
radiance_analysed.timestamp = RADIANCE_GLOBAL.timestamp;
radiance_analysed.bat_ID = RADIANCE_GLOBAL.bat_ID;
radiance_analysed.owner = ''; % currently unused
radiance_analysed.d3_file = RADIANCE_GLOBAL.d3_filename;
radiance_analysed.data_file = RADIANCE_GLOBAL.array_filename;
radiance_analysed.wamike_file = RADIANCE_GLOBAL.wamike_filename;
radiance_analysed.wagaincal_file = RADIANCE_GLOBAL.wagaincal_filename;
radiance_analysed.num_vocs = RADIANCE_GLOBAL.num_vocs;
radiance_analysed.num_mics = RADIANCE_GLOBAL.num_mics;
radiance_analysed.T_start = RADIANCE_GLOBAL.T_start;
radiance_analysed.F_start = RADIANCE_GLOBAL.F_start;
radiance_analysed.T_stop = RADIANCE_GLOBAL.T_stop;
radiance_analysed.F_stop = RADIANCE_GLOBAL.F_stop;

try
    save('-MAT',fname,'radiance_analysed');
catch
    error_code = -1; % Failed to save.
end
return


% ...depends on RADIANCE_GLOBAL, hence so few function arguments
% Returns local time of arrival for each microphone channel given reference
% emission time at the bat.
function [local_times] = bat2arrtime( t_bat )
global RADIANCE_GLOBAL;
local_times = zeros(RADIANCE_GLOBAL.num_mics,1);

for k = 1:RADIANCE_GLOBAL.num_mics
    local_times(k) = t_bat + norm( RADIANCE_GLOBAL.bat(floor(t_bat*RADIANCE_GLOBAL.vid_fps)-RADIANCE_GLOBAL.vid_start_frame+1,:) ...
                                   - RADIANCE_GLOBAL.mike_pos(k,:), 2 ) / RADIANCE_GLOBAL.spd_sound;
end


% Create axes for displaying the array signal grid
% At time of writing, the size is always 4 x 4.
function init_signal_grid
global RADIANCE_GLOBAL;

if isfield( RADIANCE_GLOBAL.handles, 'grid_axes' ) && ~isempty( RADIANCE_GLOBAL.handles.grid_axes )
    fprintf( 'Warning: attempted to re-initialize signal grid axes.\n' );
    return % Ignore request.
end

num_rows = 4;
num_cols = 4; % to be general, in case we change from 4x4 in the future.
position = [0 .3 .7 .7];
ch_width = position(3)/num_cols;
ch_height = position(4)/num_rows;
RADIANCE_GLOBAL.handles.grid_axes = zeros(num_rows*num_cols,1);
for k = 1:num_rows
    for j = 1:num_cols
        RADIANCE_GLOBAL.handles.grid_axes((k-1)*num_cols+j) = axes( 'position', ...
            [(position(1) + (j-1)*ch_width) (position(2) + (num_rows-k)*ch_height) ch_width ch_height] );
    end
end
% NOTA BENE, signal grid labeling is row-wise, i.e. axes are created moving
% left to right along the first row, then the second row, and so on.
% Ergo, for a 4x4 signal grid, RADIANCE_GLOBAL.handles.grid_axes(6)
% contains the axes for the cell at (2,2), i.e. row 2, column 2.


% Refresh Radiance plots, i.e. signal grid and channel detail view axes.
function update_plots
global RADIANCE_GLOBAL;

% Signal grid
ch_offset = (RADIANCE_GLOBAL.current_chan_group-1)*16;
intv = zeros( 16, 2 );
sig_max_ind = size(RADIANCE_GLOBAL.F,1);
for k = 1:min(16,RADIANCE_GLOBAL.num_mics-ch_offset)
    intv(k,1) = max(1,floor((RADIANCE_GLOBAL.local_times(ch_offset+k) - RADIANCE_GLOBAL.t(1)) / RADIANCE_GLOBAL.samp_period));
    intv(k,2) = intv(k,1) + RADIANCE_GLOBAL.buffer_len - 1;
    if intv(k,2) > sig_max_ind
        intv(k,2) = sig_max_ind;
        intv(k,1) = sig_max_ind - RADIANCE_GLOBAL.buffer_len + 1;
    end
end
if RADIANCE_GLOBAL.plot_type == 0 % Time waveform
   
    for k = 1:min(16,RADIANCE_GLOBAL.num_mics-ch_offset)
        %cla( RADIANCE_GLOBAL.handles.grid_axes(k) );
        plot( RADIANCE_GLOBAL.handles.grid_axes(k), RADIANCE_GLOBAL.t(intv(k,1):intv(k,2)), ...
              RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k), 'b-' );
        if ~isnan(RADIANCE_GLOBAL.T_start( ch_offset+k, RADIANCE_GLOBAL.current_voc ))
            center_val = mean(RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k));
            hold( RADIANCE_GLOBAL.handles.grid_axes(k), 'on' );
            if RADIANCE_GLOBAL.T_start( ch_offset+k, RADIANCE_GLOBAL.current_voc ) >= RADIANCE_GLOBAL.t(intv(k,1)) ...
               && RADIANCE_GLOBAL.T_start( ch_offset+k, RADIANCE_GLOBAL.current_voc ) <= RADIANCE_GLOBAL.t(intv(k,2))
                plot( RADIANCE_GLOBAL.handles.grid_axes(k), ...
                      RADIANCE_GLOBAL.T_start( ch_offset+k, RADIANCE_GLOBAL.current_voc ), center_val, 'r*' );
            end
            if RADIANCE_GLOBAL.T_stop( ch_offset+k, RADIANCE_GLOBAL.current_voc ) >= RADIANCE_GLOBAL.t(intv(k,1)) ...
               && RADIANCE_GLOBAL.T_stop( ch_offset+k, RADIANCE_GLOBAL.current_voc ) <= RADIANCE_GLOBAL.t(intv(k,2))
                plot( RADIANCE_GLOBAL.handles.grid_axes(k), ...
                      RADIANCE_GLOBAL.T_stop( ch_offset+k, RADIANCE_GLOBAL.current_voc ), center_val, 'r*' );
            end
            hold( RADIANCE_GLOBAL.handles.grid_axes(k), 'off' );
        end
        axis( RADIANCE_GLOBAL.handles.grid_axes(k), 'tight' );
        yl = ylim( RADIANCE_GLOBAL.handles.grid_axes(k) );
        if diff(yl) < 200
            mid_yl = (yl(1)+yl(2))/2;
            yl(1) = mid_yl-100;
            yl(2) = mid_yl+100;
            ylim( RADIANCE_GLOBAL.handles.grid_axes(k), yl );
        end
        set( RADIANCE_GLOBAL.handles.grid_axes(k),'xtick', [] );
        set( RADIANCE_GLOBAL.handles.grid_axes(k),'ytick', [] );
    end
    if RADIANCE_GLOBAL.num_mics-ch_offset < 16
        for k = RADIANCE_GLOBAL.num_mics-ch_offset+1:16
            set( RADIANCE_GLOBAL.handles.grid_axes(k),'xtick', [] );
            set( RADIANCE_GLOBAL.handles.grid_axes(k),'ytick', [] );
        end
    end

elseif RADIANCE_GLOBAL.plot_type == 1 % Spectrogram

    ca = zeros(16,2); % Used to ensure color scaling is comparable across channels.
    for k = 1:min(16,RADIANCE_GLOBAL.num_mics-ch_offset)
        [S,Freq,Tim,Pwr] = spectrogram( RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k) - mean(RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k)), ...
                                        RADIANCE_GLOBAL.spect_winsize, RADIANCE_GLOBAL.spect_noverlap, RADIANCE_GLOBAL.spect_nfft, ...
                                        1/RADIANCE_GLOBAL.samp_period );
        imagesc(Tim+RADIANCE_GLOBAL.t(intv(1)), Freq/1e3, 10*log10(abs(Pwr)), ...
                'Parent', RADIANCE_GLOBAL.handles.grid_axes(k));
        set(RADIANCE_GLOBAL.handles.grid_axes(k), 'YDir', 'normal');
        axis( RADIANCE_GLOBAL.handles.grid_axes(k), 'tight' );
        ca(k,:) = caxis( RADIANCE_GLOBAL.handles.grid_axes(k) );
        set( RADIANCE_GLOBAL.handles.grid_axes(k),'xtick', [] );
        set( RADIANCE_GLOBAL.handles.grid_axes(k),'ytick', [] );
    end
    if RADIANCE_GLOBAL.num_mics-ch_offset < 16
        for k = RADIANCE_GLOBAL.num_mics-ch_offset+1:16
            set( RADIANCE_GLOBAL.handles.grid_axes(k),'xtick', [] );
            set( RADIANCE_GLOBAL.handles.grid_axes(k),'ytick', [] );
        end
    end
    spca = [min(ca(:,1)) max(ca(:,2))];
    for k = 1:min(16,RADIANCE_GLOBAL.num_mics-ch_offset)
        caxis( RADIANCE_GLOBAL.handles.grid_axes(k), spca );
    end
    
elseif RADIANCE_GLOBAL.plot_type == 2 % FFT (magnitude) spectrum
    
    f = [];
    max_height = -1; % For scaling purposes
    
    for k = 1:min(16,RADIANCE_GLOBAL.num_mics-ch_offset)
        %X = fft( RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k) - mean(RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k)) );
        [X_comp, f, H] = apptrans( RADIANCE_GLOBAL.samp_period, RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k) - mean(RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k)), RADIANCE_GLOBAL.G(:,[1 ch_offset+k+1]) );
        
        %if isempty(f)
        %    f = 1/(2*RADIANCE_GLOBAL.samp_period)*linspace(0,1,length(X)/2+1);
        %end
        
        plot( RADIANCE_GLOBAL.handles.grid_axes(k), f/1e3, X_comp, 'b-' );
        xlim( RADIANCE_GLOBAL.handles.grid_axes(k), [10 130] );
        yl = ylim( RADIANCE_GLOBAL.handles.grid_axes(k) );
        if yl(2) > max_height
            max_height = yl(2);
        end
        
        set( RADIANCE_GLOBAL.handles.grid_axes(k),'xtick', [] );
        set( RADIANCE_GLOBAL.handles.grid_axes(k),'ytick', [] );
    end
    for k = 1:min(16,RADIANCE_GLOBAL.num_mics-ch_offset)
        ylim( RADIANCE_GLOBAL.handles.grid_axes(k), [0 max_height]);
    end
    if RADIANCE_GLOBAL.num_mics-ch_offset < 16
        for k = RADIANCE_GLOBAL.num_mics-ch_offset+1:16
            set( RADIANCE_GLOBAL.handles.grid_axes(k),'xtick', [] );
            set( RADIANCE_GLOBAL.handles.grid_axes(k),'ytick', [] );
        end
    end
    
elseif RADIANCE_GLOBAL.plot_type == 3 % voc FFT (mag)
    % Plot spectrum magnitudes for vocalizations marked, given current voc
    % number. Channels lacking a marked voc here are left blank.
    %
    % Note that this plot type has the same pop-out behavior as FFT (mag).
    
    f = [];
    max_height = -1; % For scaling purposes
    
    for k = 1:min(16,RADIANCE_GLOBAL.num_mics-ch_offset)

        if ~isnan(RADIANCE_GLOBAL.T_start( ch_offset+k, RADIANCE_GLOBAL.current_voc ))
            
            intv(k,1) = max(1,floor((RADIANCE_GLOBAL.T_start( ch_offset+k, RADIANCE_GLOBAL.current_voc ) - RADIANCE_GLOBAL.t(1)) / RADIANCE_GLOBAL.samp_period));
            intv(k,2) = max(1,floor((RADIANCE_GLOBAL.T_stop( ch_offset+k, RADIANCE_GLOBAL.current_voc ) - RADIANCE_GLOBAL.t(1)) / RADIANCE_GLOBAL.samp_period));
            if intv(k,2) > sig_max_ind
                intv(k,2) = sig_max_ind;
            end
            
            [X_comp, f, H] = apptrans( RADIANCE_GLOBAL.samp_period, RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k) - mean(RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k)), RADIANCE_GLOBAL.G(:,[1 ch_offset+k+1]) );
            %X = fft( RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k) - mean(RADIANCE_GLOBAL.F(intv(k,1):intv(k,2),ch_offset+k)) );
            %f = 1/(2*RADIANCE_GLOBAL.samp_period)*linspace(0,1,length(X)/2+1);

            plot( RADIANCE_GLOBAL.handles.grid_axes(k), f/1e3, X_comp, 'b-' );
            xlim( RADIANCE_GLOBAL.handles.grid_axes(k), [10 130] );
            yl = ylim( RADIANCE_GLOBAL.handles.grid_axes(k) );
            if yl(2) > max_height
                max_height = yl(2);
            end

            set( RADIANCE_GLOBAL.handles.grid_axes(k),'xtick', [] );
            set( RADIANCE_GLOBAL.handles.grid_axes(k),'ytick', [] );

        else
            cla( RADIANCE_GLOBAL.handles.grid_axes(k) );
        end

    end
    for k = 1:min(16,RADIANCE_GLOBAL.num_mics-ch_offset)
        if ~isnan(RADIANCE_GLOBAL.T_start( ch_offset+k, RADIANCE_GLOBAL.current_voc ))
            ylim( RADIANCE_GLOBAL.handles.grid_axes(k), [0 max_height]);
        end
    end
    if RADIANCE_GLOBAL.num_mics-ch_offset < 16
        for k = RADIANCE_GLOBAL.num_mics-ch_offset+1:16
            set( RADIANCE_GLOBAL.handles.grid_axes(k),'xtick', [] );
            set( RADIANCE_GLOBAL.handles.grid_axes(k),'ytick', [] );
        end
    end

else
    fprintf( 'Warning: unimplemented grid plot type %d\n', RADIANCE_GLOBAL.plot_type );
end

% Scene plot
axes(RADIANCE_GLOBAL.handles.scene_axes);
current_rel_frame = floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) - RADIANCE_GLOBAL.vid_start_frame + 1;
plot3( RADIANCE_GLOBAL.handles.scene_axes, ...
       RADIANCE_GLOBAL.bat(:,1), RADIANCE_GLOBAL.bat(:,2), RADIANCE_GLOBAL.bat(:,3), 'b-', ...
       RADIANCE_GLOBAL.bat(current_rel_frame,1), RADIANCE_GLOBAL.bat(current_rel_frame,2), RADIANCE_GLOBAL.bat(current_rel_frame,3), 'mo', ...
       RADIANCE_GLOBAL.mike_pos(:,1), RADIANCE_GLOBAL.mike_pos(:,2), RADIANCE_GLOBAL.mike_pos(:,3), 'r*' );
axis( RADIANCE_GLOBAL.handles.scene_axes, 'equal' );
grid( RADIANCE_GLOBAL.handles.scene_axes, 'on' );
set( RADIANCE_GLOBAL.handles.scene_axes, 'XTickLabel', [] );
set( RADIANCE_GLOBAL.handles.scene_axes, 'YTickLabel', [] );
set( RADIANCE_GLOBAL.handles.scene_axes, 'ZTickLabel', [] );
%view( 45, 45 );

% Detail channel view
if RADIANCE_GLOBAL.detail_chan_time_lock % If detailed view is time-sync'ed, then enforce it now.
    RADIANCE_GLOBAL.detail_stime = RADIANCE_GLOBAL.local_times( RADIANCE_GLOBAL.detail_chan );
    set(RADIANCE_GLOBAL.handles.detail_channel_tstart_box,'String', sprintf('%.2f',RADIANCE_GLOBAL.detail_stime*1e3) );
end
d_intv = [max(1,floor( (RADIANCE_GLOBAL.detail_stime - RADIANCE_GLOBAL.t(1)) / RADIANCE_GLOBAL.samp_period )) 0];
d_intv(2) = d_intv(1) + ceil(RADIANCE_GLOBAL.detail_twin/RADIANCE_GLOBAL.samp_period) - 1;
if d_intv(2) > sig_max_ind
    d_intv(2) = sig_max_ind;
    d_intv(1) = sig_max_ind - ceil(RADIANCE_GLOBAL.detail_twin/RADIANCE_GLOBAL.samp_period) + 1;
end
plot( RADIANCE_GLOBAL.handles.detail_channel_axes, ...
      RADIANCE_GLOBAL.t(d_intv(1):d_intv(2)), ...
      RADIANCE_GLOBAL.F( d_intv(1):d_intv(2), RADIANCE_GLOBAL.detail_chan ) );
axis( RADIANCE_GLOBAL.handles.detail_channel_axes, 'tight' );
xl = xlim( RADIANCE_GLOBAL.handles.detail_channel_axes );
RADIANCE_GLOBAL.detail_stime = xl(1);
set(RADIANCE_GLOBAL.handles.detail_channel_tstart_box,'String', sprintf('%.2f',RADIANCE_GLOBAL.detail_stime*1e3) );


function update_button_grid( base_num )
global RADIANCE_GLOBAL;
set(RADIANCE_GLOBAL.handles.cell11,'String',num2str(base_num));
set(RADIANCE_GLOBAL.handles.cell12,'String',num2str(base_num+1));
set(RADIANCE_GLOBAL.handles.cell13,'String',num2str(base_num+2));
set(RADIANCE_GLOBAL.handles.cell14,'String',num2str(base_num+3));
set(RADIANCE_GLOBAL.handles.cell21,'String',num2str(base_num+4));
set(RADIANCE_GLOBAL.handles.cell22,'String',num2str(base_num+5));
set(RADIANCE_GLOBAL.handles.cell23,'String',num2str(base_num+6));
set(RADIANCE_GLOBAL.handles.cell24,'String',num2str(base_num+7));
set(RADIANCE_GLOBAL.handles.cell31,'String',num2str(base_num+8));
set(RADIANCE_GLOBAL.handles.cell32,'String',num2str(base_num+9));
set(RADIANCE_GLOBAL.handles.cell33,'String',num2str(base_num+10));
set(RADIANCE_GLOBAL.handles.cell34,'String',num2str(base_num+11));
set(RADIANCE_GLOBAL.handles.cell41,'String',num2str(base_num+12));
set(RADIANCE_GLOBAL.handles.cell42,'String',num2str(base_num+13));
set(RADIANCE_GLOBAL.handles.cell43,'String',num2str(base_num+14));
set(RADIANCE_GLOBAL.handles.cell44,'String',num2str(base_num+15));



function t_window_size_box_Callback(hObject, eventdata, handles)
% hObject    handle to t_window_size_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
requested_win = str2num( get(hObject,'String') );
if isempty(requested_win) || requested_win <= 0
    set(RADIANCE_GLOBAL.handles.t_window_size_box,'String', sprintf( '%.2f', RADIANCE_GLOBAL.buffer_len * RADIANCE_GLOBAL.samp_period*1e3 ) );
    return
end
RADIANCE_GLOBAL.buffer_len = ceil((requested_win*1e-3)/RADIANCE_GLOBAL.samp_period);
set(RADIANCE_GLOBAL.handles.buf_size_box,'String', num2str(RADIANCE_GLOBAL.buffer_len) );
update_plots;


% --- Executes during object creation, after setting all properties.
function t_window_size_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to t_window_size_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function popout_gridcell( row_ind, col_ind )
global RADIANCE_GLOBAL;
ch_offset = (RADIANCE_GLOBAL.current_chan_group-1)*16;
if ch_offset + (row_ind-1)*4+col_ind > RADIANCE_GLOBAL.num_mics
    return % Ignore empty clicks (such are the times we live in).
end
if ~isnan(RADIANCE_GLOBAL.current_popped_chan)
    try close(get(RADIANCE_GLOBAL.pop_ax_h,'Parent')), catch; end % Attempt to close previous figure, if visible
end
ch_num = ch_offset + (row_ind-1)*4+col_ind;
intv = [0 0];
sig_max_ind = size(RADIANCE_GLOBAL.F,1);
intv(1) = max(1,floor((RADIANCE_GLOBAL.local_times(ch_num) - RADIANCE_GLOBAL.t(1)) / RADIANCE_GLOBAL.samp_period));
intv(2) = intv(1) + RADIANCE_GLOBAL.buffer_len - 1;
if intv(2) > sig_max_ind
    intv(2) = sig_max_ind;
end

% If current plot-type is FFT (mag) or voc FFT (mag) then popout a more
% detailed channel view of it and DO NOT prepare for voc markings on this
% "popped out" figure.
if RADIANCE_GLOBAL.plot_type == 2 % FFT (magnitude) spectrum
    fig_h = figure;
    ax_h = axes;
    [X_comp, f, H] = apptrans( RADIANCE_GLOBAL.samp_period, RADIANCE_GLOBAL.F(intv(1):intv(2),ch_num) - mean(RADIANCE_GLOBAL.F(intv(1):intv(2),ch_num)), RADIANCE_GLOBAL.G(:,[1 ch_num+1]) );
    plot( ax_h, f/1e3, X_comp, 'b.-' );
    xlim( ax_h, [10 130] );
    xlabel('Frequency (kHz)');
    ylabel('FFT magnitude (|H|)');
    title( sprintf('channel %d',ch_num) );
    return
elseif RADIANCE_GLOBAL.plot_type == 3 % voc FFT (magnitude) spectrum
    if isnan(RADIANCE_GLOBAL.T_start( ch_num, RADIANCE_GLOBAL.current_voc ))
        fprintf( 'No voc marking on channel %d.\nIgnoring detailed voc FFT (mag) plot pop-out request.\n', ch_num );
        return
    end
    fig_h = figure;
    ax_h = axes;
    intv(1) = max(1,floor((RADIANCE_GLOBAL.T_start( ch_num, RADIANCE_GLOBAL.current_voc ) - RADIANCE_GLOBAL.t(1)) / RADIANCE_GLOBAL.samp_period));
    intv(2) = max(1,floor((RADIANCE_GLOBAL.T_stop( ch_num, RADIANCE_GLOBAL.current_voc ) - RADIANCE_GLOBAL.t(1)) / RADIANCE_GLOBAL.samp_period));
    if intv(2) > sig_max_ind
        intv(2) = sig_max_ind;
    end

    [X_comp, f, H] = apptrans( RADIANCE_GLOBAL.samp_period, RADIANCE_GLOBAL.F(intv(1):intv(2),ch_num) - mean(RADIANCE_GLOBAL.F(intv(1):intv(2),ch_num)), RADIANCE_GLOBAL.G(:,[1 ch_num+1]) );
    
    plot( ax_h, f/1e3, X_comp, 'b.-' );
    xlim( ax_h, [10 130] );
    xlabel('Frequency (kHz)');
    ylabel('FFT magnitude (|H|)');
    title( sprintf('channel %d',ch_num) );
    return
end

fig_h = figure;
ax_h = axes;

[S,Freq,Tim,Pwr] = spectrogram( RADIANCE_GLOBAL.F(intv(1):intv(2),ch_num) - mean(RADIANCE_GLOBAL.F(intv(1):intv(2),ch_num)), ...
                                RADIANCE_GLOBAL.spect_winsize, RADIANCE_GLOBAL.spect_noverlap, RADIANCE_GLOBAL.spect_nfft, ...
                                1/RADIANCE_GLOBAL.samp_period );
imagesc(Tim+RADIANCE_GLOBAL.t(intv(1)), Freq/1e3, 10*log10(abs(Pwr)), 'Parent', ax_h);
set(ax_h, 'YDir', 'normal');
axis( ax_h, 'tight' );
caxis( ax_h, [RADIANCE_GLOBAL.spect_min, RADIANCE_GLOBAL.spect_max] );

% If this channel has a marking for the current vocalisation and the
% viewing window is within appropriate range, then mark start time,
% freq and stop time, freq.
if ~isnan(RADIANCE_GLOBAL.T_start( ch_num, RADIANCE_GLOBAL.current_voc ))
    hold(ax_h, 'on');
    if RADIANCE_GLOBAL.T_start(ch_num, RADIANCE_GLOBAL.current_voc) > min(Tim)+RADIANCE_GLOBAL.t(intv(1)) ...
       && RADIANCE_GLOBAL.T_start(ch_num, RADIANCE_GLOBAL.current_voc) < max(Tim)+RADIANCE_GLOBAL.t(intv(1)) ...
       && RADIANCE_GLOBAL.F_start(ch_num, RADIANCE_GLOBAL.current_voc) > min(Freq) ...
       && RADIANCE_GLOBAL.F_start(ch_num, RADIANCE_GLOBAL.current_voc) < max(Freq)
        plot(ax_h, RADIANCE_GLOBAL.T_start(ch_num, RADIANCE_GLOBAL.current_voc), ...
             RADIANCE_GLOBAL.F_start(ch_num, RADIANCE_GLOBAL.current_voc)/1e3, 'k.', 'linewidth', 2)
    end

    if RADIANCE_GLOBAL.T_stop( ch_num, RADIANCE_GLOBAL.current_voc ) > min(Tim)+RADIANCE_GLOBAL.t(intv(1)) ...
       && RADIANCE_GLOBAL.T_stop( ch_num, RADIANCE_GLOBAL.current_voc ) < max(Tim)+RADIANCE_GLOBAL.t(intv(1)) ...
       && RADIANCE_GLOBAL.F_stop( ch_num, RADIANCE_GLOBAL.current_voc ) > min(Freq) ...
       && RADIANCE_GLOBAL.F_stop( ch_num, RADIANCE_GLOBAL.current_voc ) < max(Freq)
        plot(ax_h, RADIANCE_GLOBAL.T_stop(ch_num, RADIANCE_GLOBAL.current_voc), ...
             RADIANCE_GLOBAL.F_stop(ch_num, RADIANCE_GLOBAL.current_voc)/1e3, 'k.', 'linewidth', 2)
    end
end

title( sprintf('channel %d',ch_num) );
xlabel( 'Time (s)' );
ylabel( 'Frequency (kHz)' );
RADIANCE_GLOBAL.current_popped_chan = ch_num;
RADIANCE_GLOBAL.pop_ax_h = ax_h;

if get(RADIANCE_GLOBAL.handles.mark_immed,'Value')==1
  mark_action;
end

function mark_action
global RADIANCE_GLOBAL;
if isnan(RADIANCE_GLOBAL.current_popped_chan)
    return
end

% Help prevent unintended overwrites with a confirmation dialog
if ~isnan( RADIANCE_GLOBAL.T_start( RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc ) )
    ButtonName=questdlg( sprintf('Selected channel (%d) already has a voc marking at %.4f s. Overwrite it?', ...
                                 RADIANCE_GLOBAL.current_popped_chan, ...
                                 RADIANCE_GLOBAL.T_start( RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc )), ...
                         'Marking Overwrite Confirmation', 'Yes', 'No', 'No' );
    if ~strcmpi(ButtonName,'Yes')
        return
    end
end

axes(RADIANCE_GLOBAL.pop_ax_h);
[t_marked, f_marked] = ginput(2);
if length(t_marked) ~= 2
    fprintf( 'Fewer than two points marked; ignoring.\n' );
    return
end
if t_marked(2) < t_marked(1)
    fprintf( 'Negative durations are not permitted. Ignoring.\n' );
    return
end
fprintf( 'On ch %d, marked (%.4f s, %.4f kHz) -> (%.4f s, %.4f kHz)\n', ...
         RADIANCE_GLOBAL.current_popped_chan, t_marked(1), f_marked(1), t_marked(2), f_marked(2) );
f_marked = f_marked*1e3; % Convert to Hz.
RADIANCE_GLOBAL.T_start( RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc ) = t_marked(1);
RADIANCE_GLOBAL.F_start( RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc ) = f_marked(1);
RADIANCE_GLOBAL.T_stop( RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc ) = t_marked(2);
RADIANCE_GLOBAL.F_stop( RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc ) = f_marked(2);

RADIANCE_GLOBAL.current_popped_chan = nan;
close(get(RADIANCE_GLOBAL.pop_ax_h,'Parent'));
update_plots;


% --- Executes on button press in mark_button.
function mark_button_Callback(hObject, eventdata, handles)
% hObject    handle to mark_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
mark_action;


function current_voc_box_Callback(hObject, eventdata, handles)
% hObject    handle to current_voc_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
requested_voc = str2num( get(hObject,'String') );
if isempty(requested_voc) || requested_voc < 1 || requested_voc > RADIANCE_GLOBAL.num_vocs
    set(RADIANCE_GLOBAL.handles.current_voc_box,'String',num2str( RADIANCE_GLOBAL.current_voc ) );
    return % Invalid request; ignore.
end
RADIANCE_GLOBAL.current_voc = floor(requested_voc);
set(RADIANCE_GLOBAL.handles.current_voc_box,'String',num2str( RADIANCE_GLOBAL.current_voc ) );

% If possible, set current global time according to earliest local
% vocalization start time.
I = find(~isnan(RADIANCE_GLOBAL.T_start(:,RADIANCE_GLOBAL.current_voc)));
if isempty(I)
    return
end
new_current_time = arr2bat + -RADIANCE_GLOBAL.buffer_len*RADIANCE_GLOBAL.samp_period/4;
first_bat_time = RADIANCE_GLOBAL.vid_start_frame/RADIANCE_GLOBAL.vid_fps;
if new_current_time < first_bat_time || new_current_time < RADIANCE_GLOBAL.t(1)
    if first_bat_time < RADIANCE_GLOBAL.t(1)
        RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.t(1);
    else
        RADIANCE_GLOBAL.current_time = first_bat_time;
    end
else
	RADIANCE_GLOBAL.current_time = new_current_time;
end
RADIANCE_GLOBAL.local_times = bat2arrtime( RADIANCE_GLOBAL.current_time );
set(RADIANCE_GLOBAL.handles.vidframe_box, 'String', num2str( floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) ));
set(RADIANCE_GLOBAL.handles.time_box,'String', RADIANCE_GLOBAL.current_time*1e3 );
update_plots;


% --- Executes during object creation, after setting all properties.
function current_voc_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to current_voc_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in add_voc_button.
function add_voc_button_Callback(hObject, eventdata, handles)
% hObject    handle to add_voc_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
RADIANCE_GLOBAL.num_vocs = RADIANCE_GLOBAL.num_vocs+1;
RADIANCE_GLOBAL.current_voc = RADIANCE_GLOBAL.num_vocs;
set(RADIANCE_GLOBAL.handles.current_voc_box,'String',num2str( RADIANCE_GLOBAL.current_voc ) );
tmp_T_start = RADIANCE_GLOBAL.T_start;
RADIANCE_GLOBAL.T_start = nan(RADIANCE_GLOBAL.num_mics,RADIANCE_GLOBAL.num_vocs);
RADIANCE_GLOBAL.T_start(:,1:RADIANCE_GLOBAL.num_vocs-1) = tmp_T_start;
clear tmp_T_start;
tmp_F_start = RADIANCE_GLOBAL.F_start;
RADIANCE_GLOBAL.F_start = nan(RADIANCE_GLOBAL.num_mics,RADIANCE_GLOBAL.num_vocs);
RADIANCE_GLOBAL.F_start(:,1:RADIANCE_GLOBAL.num_vocs-1) = tmp_F_start;
clear tmp_F_start;
tmp_T_stop = RADIANCE_GLOBAL.T_stop;
RADIANCE_GLOBAL.T_stop = nan(RADIANCE_GLOBAL.num_mics,RADIANCE_GLOBAL.num_vocs);
RADIANCE_GLOBAL.T_stop(:,1:RADIANCE_GLOBAL.num_vocs-1) = tmp_T_stop;
clear tmp_T_stop;
tmp_F_stop = RADIANCE_GLOBAL.F_stop;
RADIANCE_GLOBAL.F_stop = nan(RADIANCE_GLOBAL.num_mics,RADIANCE_GLOBAL.num_vocs);
RADIANCE_GLOBAL.F_stop(:,1:RADIANCE_GLOBAL.num_vocs-1) = tmp_F_stop;
clear tmp_F_stop;
update_plots;


% --- Executes on button press in delete_voc_button.
function delete_voc_button_Callback(hObject, eventdata, handles)

% Confirmation dialog
ButtonName=questdlg( 'Delete current vocalization?', ...
                     'Voc Delete Confirmation', 'Yes', 'No', 'No' );
if ~strcmpi(ButtonName,'Yes')
    return
end

global RADIANCE_GLOBAL;

% Handle special case of only one vocalization (wherein we simply clear
% existing markings.
if RADIANCE_GLOBAL.num_vocs == 1
    
    RADIANCE_GLOBAL.T_start = nan(RADIANCE_GLOBAL.num_mics,1);
    RADIANCE_GLOBAL.F_start = RADIANCE_GLOBAL.T_start;
    RADIANCE_GLOBAL.T_stop = RADIANCE_GLOBAL.T_start;
    RADIANCE_GLOBAL.F_stop = RADIANCE_GLOBAL.T_start;
    
else

    RADIANCE_GLOBAL.T_start(:,RADIANCE_GLOBAL.current_voc) = [];
    RADIANCE_GLOBAL.F_start(:,RADIANCE_GLOBAL.current_voc) = [];
    RADIANCE_GLOBAL.T_stop(:,RADIANCE_GLOBAL.current_voc) = [];
    RADIANCE_GLOBAL.F_stop(:,RADIANCE_GLOBAL.current_voc) = [];
    RADIANCE_GLOBAL.num_vocs = RADIANCE_GLOBAL.num_vocs-1;
    if RADIANCE_GLOBAL.current_voc > 1
        RADIANCE_GLOBAL.current_voc = RADIANCE_GLOBAL.current_voc-1;
    end
    
end
set(RADIANCE_GLOBAL.handles.current_voc_box,'String',num2str( RADIANCE_GLOBAL.current_voc ) );
update_plots;

% --- Executes on button press in prev_voc_button.
function prev_voc_button_Callback(hObject, eventdata, handles)
% hObject    handle to prev_voc_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
if RADIANCE_GLOBAL.current_voc == 1
    return % Ignore silly requests.
end
RADIANCE_GLOBAL.current_voc = RADIANCE_GLOBAL.current_voc-1;
set(RADIANCE_GLOBAL.handles.current_voc_box,'String',num2str( RADIANCE_GLOBAL.current_voc ) );
I = find(~isnan(RADIANCE_GLOBAL.T_start(:,RADIANCE_GLOBAL.current_voc)));
if isempty(I)
    update_plots; % To ensure call markings from previous vocalization are not still there.
    return
end
new_current_time = arr2bat + -RADIANCE_GLOBAL.buffer_len*RADIANCE_GLOBAL.samp_period/4;
first_bat_time = RADIANCE_GLOBAL.vid_start_frame/RADIANCE_GLOBAL.vid_fps;
if new_current_time < first_bat_time || new_current_time < RADIANCE_GLOBAL.t(1)
    if first_bat_time < RADIANCE_GLOBAL.t(1)
        RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.t(1);
    else
        RADIANCE_GLOBAL.current_time = first_bat_time;
    end
else
	RADIANCE_GLOBAL.current_time = new_current_time;
end
RADIANCE_GLOBAL.local_times = bat2arrtime( RADIANCE_GLOBAL.current_time );
set(RADIANCE_GLOBAL.handles.vidframe_box, 'String', num2str( floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) ));
set(RADIANCE_GLOBAL.handles.time_box,'String', RADIANCE_GLOBAL.current_time*1e3 );
update_plots;


% --- Executes on button press in next_voc_button.
function next_voc_button_Callback(hObject, eventdata, handles)
% hObject    handle to next_voc_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global RADIANCE_GLOBAL;
if RADIANCE_GLOBAL.current_voc == RADIANCE_GLOBAL.num_vocs
    return % Ignore silly requests.
end
RADIANCE_GLOBAL.current_voc = RADIANCE_GLOBAL.current_voc+1;
set(RADIANCE_GLOBAL.handles.current_voc_box,'String',num2str( RADIANCE_GLOBAL.current_voc ) );
I = find(~isnan(RADIANCE_GLOBAL.T_start(:,RADIANCE_GLOBAL.current_voc)));
if isempty(I)
    update_plots; % To ensure call markings from previous vocalization are not still there.
    return
end
[new_current_time, nct_ref_chan] = min(RADIANCE_GLOBAL.T_start(I,RADIANCE_GLOBAL.current_voc));
new_current_time = arr2bat + -RADIANCE_GLOBAL.buffer_len*RADIANCE_GLOBAL.samp_period/4;
first_bat_time = RADIANCE_GLOBAL.vid_start_frame/RADIANCE_GLOBAL.vid_fps;
if new_current_time < first_bat_time || new_current_time < RADIANCE_GLOBAL.t(1)
    if first_bat_time < RADIANCE_GLOBAL.t(1)
        RADIANCE_GLOBAL.current_time = RADIANCE_GLOBAL.t(1);
    else
        RADIANCE_GLOBAL.current_time = first_bat_time;
    end
else
	RADIANCE_GLOBAL.current_time = new_current_time;
end
RADIANCE_GLOBAL.local_times = bat2arrtime( RADIANCE_GLOBAL.current_time );
set(RADIANCE_GLOBAL.handles.vidframe_box, 'String', num2str( floor(RADIANCE_GLOBAL.current_time*RADIANCE_GLOBAL.vid_fps) ));
set(RADIANCE_GLOBAL.handles.time_box,'String', RADIANCE_GLOBAL.current_time*1e3 );
update_plots;


% --- Executes on button press in mk_voc_marks_chrono_button.
function mk_voc_marks_chrono_button_Callback(hObject, eventdata, handles)

global RADIANCE_GLOBAL;
if isempty(RADIANCE_GLOBAL.T_start) || size(RADIANCE_GLOBAL.T_start,2) == 1
    return % Ignore silly requests
end

% Confirmation dialog
ButtonName=questdlg( 'Sort voc markings to achieve chronological ordering? Note that this is merely to make later viewing easier, but does not alter data analysis results.', ...
                     'Sort Markings Confirmation', 'Yes', 'No', 'No' );
if ~strcmpi(ButtonName,'Yes')
    return
end

sort_voc_marks;
RADIANCE_GLOBAL.current_voc = 1; % Jump back to first voc marking (which may be empty).
set(RADIANCE_GLOBAL.handles.current_voc_box,'String',num2str( RADIANCE_GLOBAL.current_voc ) );
update_plots;


function sort_voc_marks
global RADIANCE_GLOBAL;
for k = 1:RADIANCE_GLOBAL.num_mics
   
    I = find(~isnan( RADIANCE_GLOBAL.T_start(k,:) ));
    if isempty(I)
        continue
    end
    
    [T_sorted, I_map] = sort( RADIANCE_GLOBAL.T_start(k,I) );
    prev_T_start = RADIANCE_GLOBAL.T_start;
    prev_F_start = RADIANCE_GLOBAL.F_start;
    prev_T_stop = RADIANCE_GLOBAL.T_stop;
    prev_F_stop = RADIANCE_GLOBAL.F_stop;
    for j = 1:length(I_map)
        RADIANCE_GLOBAL.T_start(:,I(j)) = prev_T_start(:,I(I_map(j)));
        RADIANCE_GLOBAL.F_start(:,I(j)) = prev_F_start(:,I(I_map(j)));
        RADIANCE_GLOBAL.T_stop(:,I(j)) = prev_T_stop(:,I(I_map(j)));
        RADIANCE_GLOBAL.F_stop(:,I(j)) = prev_F_stop(:,I(I_map(j)));
    end
    
end


% --- Executes on button press in gen_beam_button.
function gen_beam_button_Callback(hObject, eventdata, handles)

global RADIANCE_GLOBAL;
I = find(~isnan( RADIANCE_GLOBAL.T_start(:,RADIANCE_GLOBAL.current_voc) ));
if isempty(I)
    fprintf( 'No channels marked for current vocalization. Ignoring gen-beam request.\n' );
    return % Ignore request if there's nothing to draw.
end

call_current_time = arr2bat;
current_rel_frame = floor(call_current_time*RADIANCE_GLOBAL.vid_fps) - RADIANCE_GLOBAL.vid_start_frame + 1;

chan_vects = genbeam( RADIANCE_GLOBAL.mike_pos, RADIANCE_GLOBAL.G, ...
                      RADIANCE_GLOBAL.F, RADIANCE_GLOBAL.t, RADIANCE_GLOBAL.samp_period, ...
                      RADIANCE_GLOBAL.temp, RADIANCE_GLOBAL.rel_humid, ...
                      RADIANCE_GLOBAL.bat(current_rel_frame,:), RADIANCE_GLOBAL.T_start, RADIANCE_GLOBAL.T_stop, ...
                      [RADIANCE_GLOBAL.beam_lo_freq RADIANCE_GLOBAL.beam_hi_freq], ...
                      RADIANCE_GLOBAL.current_voc );

I = find( ~isnan( chan_vects(:,1) ) );
I_not = find( isnan( chan_vects(:,1) ) );
if isempty(I)
    return % Failed to generate any beam vectors; drop out silently.
end

% Normalize chan_vect lengths
cv_len = zeros(size(I));
for k = 1:length(I)
    cv_len(k) = norm( chan_vects(I(k),:), 2 );
end
max_cv_len = max(cv_len);
for k = 1:length(I)
    chan_vects(I(k),:) = chan_vects(I(k),:)/max_cv_len*2;
end

chan_vects_full = zeros(length(I)*3,3); % For pretty plotting
for k = 1:length(I)
    chan_vects_full((k-1)*3+2,:) = chan_vects(I(k),:);
    %chan_vects_full((k-1)*3+1:(k-1)*3+3,:) = chan_vects_full((k-1)*3+1:(k-1)*3+3,:) + [1;1;1]*RADIANCE_GLOBAL.mike_pos(I(k),:); % w.r.t. microphone
    chan_vects_full((k-1)*3+1:(k-1)*3+3,:) = chan_vects_full((k-1)*3+1:(k-1)*3+3,:) + [1;1;1]*RADIANCE_GLOBAL.bat(current_rel_frame,:); % w.r.t. bat
end

fig_h = figure;
ax_h = axes;
plot3( ax_h, ...
       RADIANCE_GLOBAL.bat(:,1), RADIANCE_GLOBAL.bat(:,2), RADIANCE_GLOBAL.bat(:,3), 'b-', ...
       RADIANCE_GLOBAL.bat(current_rel_frame,1), RADIANCE_GLOBAL.bat(current_rel_frame,2), RADIANCE_GLOBAL.bat(current_rel_frame,3), 'mo', ...
       RADIANCE_GLOBAL.mike_pos(I,1), RADIANCE_GLOBAL.mike_pos(I,2), RADIANCE_GLOBAL.mike_pos(I,3), 'r*' );%, ...
       %RADIANCE_GLOBAL.mike_pos(I_not,1), RADIANCE_GLOBAL.mike_pos(I_not,2), RADIANCE_GLOBAL.mike_pos(I_not,3), 'b*' );
hold( ax_h, 'on' );
for k = 1:length(I)
    plot3( chan_vects_full((k-1)*3+1:(k-1)*3+3,1),chan_vects_full((k-1)*3+1:(k-1)*3+3,2),chan_vects_full((k-1)*3+1:(k-1)*3+3,3), 'md-' );
end
hold( ax_h, 'off' );
axis( ax_h, 'equal' );
grid( ax_h, 'on' );
title( ax_h, sprintf( '%.3f - %.3f kHz; voc %d', RADIANCE_GLOBAL.beam_lo_freq/1e3, RADIANCE_GLOBAL.beam_hi_freq/1e3, RADIANCE_GLOBAL.current_voc ));


function low_freq_box_Callback(hObject, eventdata, handles)

global RADIANCE_GLOBAL;

requested_freq = str2num( get(hObject,'String') );
if isempty(requested_freq) || requested_freq < 0 ...
   || requested_freq*1e3 > RADIANCE_GLOBAL.beam_hi_freq || requested_freq*1e3 > 1/(RADIANCE_GLOBAL.samp_period*2)
    set(RADIANCE_GLOBAL.handles.low_freq_box,'String', sprintf('%.3f',RADIANCE_GLOBAL.beam_lo_freq/1e3) );
    return
end

RADIANCE_GLOBAL.beam_lo_freq = requested_freq*1e3; % store as Hz
set(RADIANCE_GLOBAL.handles.low_freq_box,'String', sprintf('%.3f',RADIANCE_GLOBAL.beam_lo_freq/1e3) );


% --- Executes during object creation, after setting all properties.
function low_freq_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to low_freq_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function high_freq_box_Callback(hObject, eventdata, handles)

global RADIANCE_GLOBAL;

requested_freq = str2num( get(hObject,'String') );
if isempty(requested_freq) || requested_freq < 0 ...
   || requested_freq*1e3 < RADIANCE_GLOBAL.beam_lo_freq || requested_freq*1e3 > 1/(RADIANCE_GLOBAL.samp_period*2)
    set(RADIANCE_GLOBAL.handles.high_freq_box,'String', sprintf('%.3f',RADIANCE_GLOBAL.beam_hi_freq/1e3) );
    return
end

RADIANCE_GLOBAL.beam_hi_freq = requested_freq*1e3; % store as Hz
set(RADIANCE_GLOBAL.handles.high_freq_box,'String', sprintf('%.3f',RADIANCE_GLOBAL.beam_hi_freq/1e3) );


% --- Executes during object creation, after setting all properties.
function high_freq_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to high_freq_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in detail_chan_view_time_lock.
function detail_chan_view_time_lock_Callback(hObject, eventdata, handles)
global RADIANCE_GLOBAL;
RADIANCE_GLOBAL.detail_chan_time_lock =  floor(get(hObject,'Value'));
update_plots;


% --- Executes on button press in kill_marking_button.
function kill_marking_button_Callback(hObject, eventdata, handles)

global RADIANCE_GLOBAL;
if isnan(RADIANCE_GLOBAL.current_popped_chan)
    fprintf( 'No channel active. Ignoring "kill" request.\n' );
    return
end

if isnan( RADIANCE_GLOBAL.T_start( RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc ) )
    fprintf( 'There is no voc marking for channel %d. Ignoring request.\n', RADIANCE_GLOBAL.current_popped_chan );
    return
end

% Help prevent unintended death with a confirmation dialog
ButtonName=questdlg( sprintf('Erase current voc marking for channel %d?  (Vocalization is num. %d.)', ...
                             RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc), ...
                     'Marking Overwrite Confirmation', 'Yes', 'No', 'No' );
if ~strcmpi(ButtonName,'Yes')
    return
end

RADIANCE_GLOBAL.T_start( RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc ) = NaN;
RADIANCE_GLOBAL.F_start( RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc ) = NaN;
RADIANCE_GLOBAL.T_stop( RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc ) = NaN;
RADIANCE_GLOBAL.F_stop( RADIANCE_GLOBAL.current_popped_chan, RADIANCE_GLOBAL.current_voc ) = NaN;

RADIANCE_GLOBAL.current_popped_chan = nan;
close(get(RADIANCE_GLOBAL.pop_ax_h,'Parent'));
update_plots;


% Convert local call times on channels to most likely emission time at bat.
% Only non-NaN time values are used; returns empty matrix on error, or if
% no times are available on any mic channel.
function [current_time] = arr2bat

global RADIANCE_GLOBAL;

bat_len = length(RADIANCE_GLOBAL.bat); % Assuming we have at least 3 bat positions.
bat_start_time = RADIANCE_GLOBAL.vid_start_frame/RADIANCE_GLOBAL.vid_fps;
mic_votes = nan(RADIANCE_GLOBAL.num_mics,1);
for k = 1:RADIANCE_GLOBAL.num_mics
    
    if isnan(RADIANCE_GLOBAL.T_start(k,RADIANCE_GLOBAL.current_voc))
        mic_votes(k) = NaN; % To be deleted before the election
    else
        
        if (bat_len-1)*RADIANCE_GLOBAL.samp_period + bat_start_time > RADIANCE_GLOBAL.T_start(k,RADIANCE_GLOBAL.current_voc)
            % Only consider source positions occurring at or before arrival
            % time at microphone
            N = max( ceil((RADIANCE_GLOBAL.T_start(k,RADIANCE_GLOBAL.current_voc) - bat_start_time)/RADIANCE_GLOBAL.samp_period), 1 );
        else
            N = bat_len;
        end

        min_ind = 1;
        min_err = abs( norm( RADIANCE_GLOBAL.mike_pos(k,:) - RADIANCE_GLOBAL.bat(min_ind,:), 2 ) ...
                       - RADIANCE_GLOBAL.spd_sound*(RADIANCE_GLOBAL.T_start(k,RADIANCE_GLOBAL.current_voc) - ((min_ind-1)/RADIANCE_GLOBAL.vid_fps+bat_start_time)) );
        for curr_ind = 2:N
            curr_err = abs( norm( RADIANCE_GLOBAL.mike_pos(k,:) - RADIANCE_GLOBAL.bat(curr_ind,:), 2 ) ...
                            - RADIANCE_GLOBAL.spd_sound*(RADIANCE_GLOBAL.T_start(k,RADIANCE_GLOBAL.current_voc) - ((curr_ind-1)/RADIANCE_GLOBAL.vid_fps+bat_start_time)) );
            if curr_err <= min_err
                min_ind = curr_ind;
                min_err = curr_err;
            end
        end

        mic_votes(k) = ((min_ind-1)/RADIANCE_GLOBAL.vid_fps+bat_start_time);
        
    end
    
end

% Currently, votes are equally weighted
I = find(isnan(mic_votes));
mic_votes(I) = []; % Delete not-a-number (NaN) entries.
current_time = mean( mic_votes );
return


% --------------------------------------------------------------------
function view_gain_adj_mag_Callback(hObject, eventdata, handles)
global RADIANCE_GLOBAL;
if isempty(RADIANCE_GLOBAL.wagaincal_filename)
    return % Ignore empty states
end
fig_h = figure;
ax_h = axes;
plot( ax_h, RADIANCE_GLOBAL.G(:,1)/1e3, RADIANCE_GLOBAL.G(:,2:end), '.-' );
axis( ax_h, 'tight' );
xlabel( 'kHz' );
ylabel( '|H|' );
title( 'gain magnitude compensation' );
for k = 1:RADIANCE_GLOBAL.num_mics
    % Mark channel numbers at the start and stop of the traces.
    text(RADIANCE_GLOBAL.G(end,1)/1e3,RADIANCE_GLOBAL.G(end,k+1), sprintf('% 3d',k) );
    text(RADIANCE_GLOBAL.G(1,1)/1e3,RADIANCE_GLOBAL.G(1,k+1), sprintf('% 3d',k) );
end


% --------------------------------------------------------------------
function change_gaincal_file_Callback(hObject, eventdata, handles)
global RADIANCE_GLOBAL;
if isempty(RADIANCE_GLOBAL.array_filename)
    return % Ignore request if no trial analysis is active
end
[wagaincal_filename, pathname] = uigetfile( '*.wagaincal.mat', 'Select gain calibration', RADIANCE_GLOBAL.def_dir );
if isequal(wagaincal_filename,0)
    return % User hit Cancel button.
else
    wagaincal_filename = [pathname wagaincal_filename];
end
fprintf( 'Reading gain calibration file... ');
try
    gf = load('-MAT', wagaincal_filename );
    if ~isfield(gf, 'G' )
        fprintf('FAIL!\n');
        return
    end
    fprintf('Done.\n');
catch
    fprintf( 'FAIL!\n' );
    return
end
RADIANCE_GLOBAL.wagaincal_filename = wagaincal_filename;
RADIANCE_GLOBAL.G = gf.G;
if isfield(gf,'freq_divs')
    RADIANCE_GLOBAL.freq_divs = gf.freq_divs;
end
dmarks = strfind( RADIANCE_GLOBAL.wagaincal_filename, '\' );
if isempty(dmarks)
    dmarks = [0];
end
set(RADIANCE_GLOBAL.handles.wagaincal_filename_box, 'String', RADIANCE_GLOBAL.wagaincal_filename(dmarks(end)+1:end) );
set(RADIANCE_GLOBAL.handles.wagaincal_filename_box, 'TooltipString', RADIANCE_GLOBAL.wagaincal_filename );
update_plots;



function spectrogram_max_box_Callback(hObject, eventdata, handles)
global RADIANCE_GLOBAL;
requested_max = str2num( get(hObject,'String') );
if isempty(requested_max) || requested_max < RADIANCE_GLOBAL.spect_min
    set(RADIANCE_GLOBAL.handles.spectrogram_max_box,'String', num2str(RADIANCE_GLOBAL.spect_max) );
    return % Invalid max; ignore.
end
RADIANCE_GLOBAL.spect_max = requested_max;
return


% --- Executes during object creation, after setting all properties.
function spectrogram_max_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to spectrogram_max_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function spectrogram_min_box_Callback(hObject, eventdata, handles)
global RADIANCE_GLOBAL;
requested_min = str2num( get(hObject,'String') );
if isempty(requested_min) || requested_min > RADIANCE_GLOBAL.spect_max
    set(RADIANCE_GLOBAL.handles.spectrogram_min_box,'String', num2str(RADIANCE_GLOBAL.spect_min) );
    return % Invalid min; ignore.
end
RADIANCE_GLOBAL.spect_min = requested_min;
return


function set_spect_params_Callback(hObject, eventdata, handles)
global RADIANCE_GLOBAL;
if isempty(RADIANCE_GLOBAL.array_filename)
    fprintf('No session active. Ignoring request.\n');
    return
end

answer = inputdlg({'Window width:', 'NOVERLAP:', 'NFFT:'}, 'Spectrogram parameters', 1, ...
                  {num2str(RADIANCE_GLOBAL.spect_winsize), ...
                   num2str(RADIANCE_GLOBAL.spect_noverlap), ...
                   num2str(RADIANCE_GLOBAL.spect_nfft)});
if isempty(answer)
    return % User hit cancel; do nothing.
end

% Sanity-checks
new_winsize = str2double(answer{1});
new_noverlap = str2double(answer{2});
new_nfft = str2double(answer{3});
if new_winsize <= 0 || new_noverlap <= 0 || new_nfft <= 0 ...
   || new_winsize-floor(new_winsize) ~= 0 || new_noverlap-floor(new_noverlap) ~= 0 || new_nfft-floor(new_nfft) ~= 0 ...
   || new_winsize < new_noverlap
    fprintf( 'Warning: invalid spectrogram parameters. Ignoring.\n' );
    return % It's all-or-nothing
end

RADIANCE_GLOBAL.spect_winsize = new_winsize;
RADIANCE_GLOBAL.spect_noverlap = new_noverlap;
RADIANCE_GLOBAL.spect_nfft = new_nfft;
update_plots; % Refresh all plots, given new parameters.


% --- Executes during object creation, after setting all properties.
function spectrogram_min_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to spectrogram_min_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in mark_immed.
function mark_immed_Callback(hObject, eventdata, handles)
% hObject    handle to mark_immed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of mark_immed
