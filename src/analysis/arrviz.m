% Arrviz - microphone array visualization and analysis.
%
% Scott Livingston <slivingston@caltech.edu>
% Oct 2009.
%
% NOTES: - Mode key: 1 => oscillogram
%                    2 => spectrogram

function varargout = arrviz(varargin)
% ARRVIZ M-file for arrviz.fig
%      ARRVIZ, by itself, creates a new ARRVIZ or raises the existing
%      singleton*.
%
%      H = ARRVIZ returns the handle to a new ARRVIZ or the handle to
%      the existing singleton*.
%
%      ARRVIZ('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in ARRVIZ.M with the given input arguments.
%
%      ARRVIZ('Property','Value',...) creates a new ARRVIZ or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before arrviz_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to arrviz_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help arrviz

% Last Modified by GUIDE v2.5 19-Oct-2009 17:32:44

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @arrviz_OpeningFcn, ...
                   'gui_OutputFcn',  @arrviz_OutputFcn, ...
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


% --- Executes just before arrviz is made visible.
function arrviz_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to arrviz (see VARARGIN)

% Choose default command line output for arrviz
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% initialize main structure
global ARRVIZ_GLOBAL;
ARRVIZ_GLOBAL = [];
ARRVIZ_GLOBAL.FL_datafile = [];
ARRVIZ_GLOBAL.ML_datafile = [];
ARRVIZ_GLOBAL.MR_datafile = [];
ARRVIZ_GLOBAL.FR_datafile = [];
ARRVIZ_GLOBAL.time_range = [0 1];
ARRVIZ_GLOBAL.freq_band = [10e3 100e3];
ARRVIZ_GLOBAL.current_trial = 1;
ARRVIZ_GLOBAL.analysis_mode = 1; % default to oscillogram
ARRVIZ_GLOBAL.t = []; % vector of timestamps (units of seconds since trigger press)
ARRVIZ_GLOBAL.trial_data = [];
% trial_data is an NxM matrix, where N is the number of samples,
% and M is the number of microphone channels.

ARRVIZ_GLOBAL.handles = [];

axheight = .17;
axwidth = .2;
axpos = ones(16,4)*axwidth;
axpos(:,4) = ones(16,1)*axheight;
for k = 1:4
    axpos([k k+4 k+8 k+12],2) = .22 + axheight*(4-k);
    axpos((1+(k-1)*4):(4+(k-1)*4),1) = .1 + axwidth*(k-1);
end

for k = 1:16
    ARRVIZ_GLOBAL.handles(k) = axes( 'position', axpos(k,:), 'XTickLabel', '', 'YTickLabel', '' );
end


% UIWAIT makes arrviz wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = arrviz_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ARRVIZ_GLOBAL;

[fname,pname] = uigetfile( '*', 'Select a Data file for Far Left mic column' );
if isequal(fname,0) || isequal(pname,0) % User hit cancel button?
    return
end

[hdr,trials,t] = loadsdtrials( [pname fname], ARRVIZ_GLOBAL.current_trial );

if hdr(2) < ARRVIZ_GLOBAL.current_trial
    return % fail silently, return to original state (before attempted data file open)
end

ARRVIZ_GLOBAL.FL_datafile = [pname fname];

% update number of trials in Trials popup menu
trial_strings = cell(1,hdr(2));
for k = 1:hdr(2)
    trial_strings{k} = num2str(k);
end
trials_popuph = findobj( 'Tag', 'popupmenu1' );
set( trials_popuph, 'String', trial_strings );

if isempty(ARRVIZ_GLOBAL.trial_data)
    ARRVIZ_GLOBAL.trial_data = zeros( length(t), 16 );
end

for k = 1:4
    ARRVIZ_GLOBAL.trial_data(:,k) = trials{ARRVIZ_GLOBAL.current_trial}(k:4:end);
end
ARRVIZ_GLOBAL.t = t;

update_grid( 1:4 );


% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ARRVIZ_GLOBAL;

[fname,pname] = uigetfile( '*', 'Select a Data file for Mid Left mic column' );
if isequal(fname,0) || isequal(pname,0) % User hit cancel button?
    return
end

[hdr,trials,t] = loadsdtrials( [pname fname], ARRVIZ_GLOBAL.current_trial );

if hdr(2) < ARRVIZ_GLOBAL.current_trial
    return % fail silently, return to original state (before attempted data file open)
end

ARRVIZ_GLOBAL.ML_datafile = [pname fname];

% update number of trials in Trials popup menu
trial_strings = cell(1,hdr(2));
for k = 1:hdr(2)
    trial_strings{k} = num2str(k);
end
trials_popuph = findobj( 'Tag', 'popupmenu1' );
set( trials_popuph, 'String', trial_strings );

if isempty(ARRVIZ_GLOBAL.trial_data)
    ARRVIZ_GLOBAL.trial_data = zeros( length(t), 16 );
end

for k = 1:4
    ARRVIZ_GLOBAL.trial_data(:,k+4) = trials{ARRVIZ_GLOBAL.current_trial}(k:4:end);
end
ARRVIZ_GLOBAL.t = t;

update_grid( 5:8 );


% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ARRVIZ_GLOBAL;

[fname,pname] = uigetfile( '*', 'Select a Data file for Mid Right mic column' );
if isequal(fname,0) || isequal(pname,0) % User hit cancel button?
    return
end

[hdr,trials,t] = loadsdtrials( [pname fname], ARRVIZ_GLOBAL.current_trial );

if hdr(2) < ARRVIZ_GLOBAL.current_trial
    return % fail silently, return to original state (before attempted data file open)
end

ARRVIZ_GLOBAL.MR_datafile = [pname fname];

% update number of trials in Trials popup menu
trial_strings = cell(1,hdr(2));
for k = 1:hdr(2)
    trial_strings{k} = num2str(k);
end
trials_popuph = findobj( 'Tag', 'popupmenu1' );
set( trials_popuph, 'String', trial_strings );

if isempty(ARRVIZ_GLOBAL.trial_data)
    ARRVIZ_GLOBAL.trial_data = zeros( length(t), 16 );
end

for k = 1:4
    ARRVIZ_GLOBAL.trial_data(:,k+8) = trials{ARRVIZ_GLOBAL.current_trial}(k:4:end);
end
ARRVIZ_GLOBAL.t = t;

update_grid( 9:12 );


% --- Executes on button press in pushbutton4.
function pushbutton4_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ARRVIZ_GLOBAL;

[fname,pname] = uigetfile( '*', 'Select a Data file for Far Right mic column' );
if isequal(fname,0) || isequal(pname,0) % User hit cancel button?
    return
end

[hdr,trials,t] = loadsdtrials( [pname fname], ARRVIZ_GLOBAL.current_trial );

if hdr(2) < ARRVIZ_GLOBAL.current_trial
    return % fail silently, return to original state (before attempted data file open)
end

ARRVIZ_GLOBAL.FR_datafile = [pname fname];

% update number of trials in Trials popup menu
trial_strings = cell(1,hdr(2));
for k = 1:hdr(2)
    trial_strings{k} = num2str(k);
end
trials_popuph = findobj( 'Tag', 'popupmenu1' );
set( trials_popuph, 'String', trial_strings );

if isempty(ARRVIZ_GLOBAL.trial_data)
    ARRVIZ_GLOBAL.trial_data = zeros( length(t), 16 );
end

for k = 1:4
    ARRVIZ_GLOBAL.trial_data(:,k+12) = trials{ARRVIZ_GLOBAL.current_trial}(k:4:end);
end
if length(ARRVIZ_GLOBAL.t) ~= length(t)
    ARRVIZ_GLOBAL.t = t;
end

update_grid( 13:16 );


% --- Executes on selection change in popupmenu1.
function popupmenu1_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns popupmenu1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu1

global ARRVIZ_GLOBAL;

new_trial = get(hObject,'Value');
if ARRVIZ_GLOBAL.current_trial ~= new_trial
    ARRVIZ_GLOBAL.current_trial = new_trial;
    reload_trialdata();
    update_grid( 1:16 );
end


% --- Executes during object creation, after setting all properties.
function popupmenu1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in popupmenu2.
function popupmenu2_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns popupmenu2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu2

% See notes at top of source file for numeric mode key.

global ARRVIZ_GLOBAL;

new_mode = get(hObject,'Value');
if ARRVIZ_GLOBAL.analysis_mode ~= new_mode
    ARRVIZ_GLOBAL.analysis_mode = new_mode;
    update_grid( 1:16 );
end


% --- Executes during object creation, after setting all properties.
function popupmenu2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double

global ARRVIZ_GLOBAL;
newval = str2double(get(hObject,'String'));
if newval >= 0 && newval <= ARRVIZ_GLOBAL.freq_band(2)
    ARRVIZ_GLOBAL.freq_band(1) = newval*1e3;
else % invalid change
    set(hObject,'String',num2str(ARRVIZ_GLOBAL.freq_band(1)));
    return
end

update_grid( 1:16 );


% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit2_Callback(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit2 as text
%        str2double(get(hObject,'String')) returns contents of edit2 as a double

global ARRVIZ_GLOBAL;
newval = str2double(get(hObject,'String'));
if newval <= 100e3 && newval >= ARRVIZ_GLOBAL.freq_band(1)
    ARRVIZ_GLOBAL.freq_band(2) = newval*1e3;
else % invalid change
    set(hObject,'String',num2str(ARRVIZ_GLOBAL.freq_band(2)));
    return
end

update_grid( 1:16 );


% --- Executes during object creation, after setting all properties.
function edit2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit3_Callback(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit3 as text
%        str2double(get(hObject,'String')) returns contents of edit3 as a double

global ARRVIZ_GLOBAL;
newval = str2double(get(hObject,'String'));
if newval >= 0 && newval <= ARRVIZ_GLOBAL.time_range(2)
    ARRVIZ_GLOBAL.time_range(1) = newval;
else % invalid change
    set(hObject,'String',num2str(ARRVIZ_GLOBAL.time_range(1)));
    return
end

update_grid( 1:16 );


% --- Executes during object creation, after setting all properties.
function edit3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit4_Callback(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit4 as text
%        str2double(get(hObject,'String')) returns contents of edit4 as a double

global ARRVIZ_GLOBAL;
newval = str2double(get(hObject,'String'));
if newval <= 4 && newval >= ARRVIZ_GLOBAL.time_range(1)
    ARRVIZ_GLOBAL.time_range(2) = newval;
else % invalid change
    set(hObject,'String',num2str(ARRVIZ_GLOBAL.time_range(2)));
    return
end

update_grid( 1:16 );


% --- Executes during object creation, after setting all properties.
function edit4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function pushbutton1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


function update_grid( cells_to_update )

global ARRVIZ_GLOBAL;

% ignore duds
if isempty(ARRVIZ_GLOBAL.t)
    return
end

% find indices corresponding to desired time range
xl = [max(find(ARRVIZ_GLOBAL.t <= ARRVIZ_GLOBAL.time_range(1)));
      min(find(ARRVIZ_GLOBAL.t >= ARRVIZ_GLOBAL.time_range(2)))]';

switch ARRVIZ_GLOBAL.analysis_mode

    case 1 % oscillogram
        % for oscillograms, assume voltage range is 0 to 3.3 V.
        for k = cells_to_update

            set( gcf, 'CurrentAxes', ARRVIZ_GLOBAL.handles(k) );
            %cla;
            plot( ARRVIZ_GLOBAL.t(xl(1):xl(2)), ARRVIZ_GLOBAL.trial_data( xl(1):xl(2), k ) );
            if k == 4 % reference annotation
                xlabel( 'time (s)' );
                ylabel( 'channel signal (V)' );
            else
                set( gca, 'XTickLabel', '', 'YTickLabel', '' );
            end
            axis( [ARRVIZ_GLOBAL.t(xl) 0 3.3]);

        end
        drawnow;
        
    case 2 % spectrogram
        % remove mean (or 0 Hz frequency component),
        % assume ADC sampling rate of 250 kHz.
        for k = cells_to_update

            set( gcf, 'CurrentAxes', ARRVIZ_GLOBAL.handles(k) );
            %cla;
            spectrogram( ARRVIZ_GLOBAL.trial_data( xl(1):xl(2), k ) - mean(ARRVIZ_GLOBAL.trial_data( xl(1):xl(2), k )), ...
                         128, 120, 256, 250e3, 'yaxis' );
            if k == 4 % reference annotation
                %xlabel( 'time (s)' );
                %ylabel( 'frequency (Hz)' );
            else
                set( gca, 'XTickLabel', '', 'YTickLabel', '' );
                %set( get(gca,'XLabel'), 'String', '' );
                %set( get(gca,'YLabel'), 'String', '' );
                xlabel('');
                ylabel('');
            end
            %axis( [ARRVIZ_GLOBAL.t(xl) ARRVIZ_GLOBAL.freq_band]);
            ylim(ARRVIZ_GLOBAL.freq_band);
            
            % set common color scale
            if k == cells_to_update(1)
                ref_ca = caxis;
            end

        end
        for k = 1:16
            set( gcf, 'CurrentAxes', ARRVIZ_GLOBAL.handles(k) );
            caxis( ref_ca );
        end
        drawnow;
        
end


function reload_trialdata()

global ARRVIZ_GLOBAL;

if ~isempty(ARRVIZ_GLOBAL.FL_datafile)
    [hdr,trials,t] = loadsdtrials( ARRVIZ_GLOBAL.FL_datafile, ARRVIZ_GLOBAL.current_trial );

    if hdr(2) < ARRVIZ_GLOBAL.current_trial
        return % fail silently
    end

    % update number of trials in Trials popup menu
    trial_strings = cell(1,hdr(2));
    for k = 1:hdr(2)
        trial_strings{k} = num2str(k);
    end
    trials_popuph = findobj( 'Tag', 'popupmenu1' );
    set( trials_popuph, 'String', trial_strings );

    if isempty(ARRVIZ_GLOBAL.trial_data)
        ARRVIZ_GLOBAL.trial_data = zeros( length(t), 16 );
    end

    for k = 1:4
        ARRVIZ_GLOBAL.trial_data(:,k) = trials{ARRVIZ_GLOBAL.current_trial}(k:4:end);
    end
    ARRVIZ_GLOBAL.t = t;
end

if ~isempty(ARRVIZ_GLOBAL.ML_datafile)
    [hdr,trials,t] = loadsdtrials( ARRVIZ_GLOBAL.ML_datafile, ARRVIZ_GLOBAL.current_trial );

    if hdr(2) < ARRVIZ_GLOBAL.current_trial
        return % fail silently, return to original state (before attempted data file open)
    end

    % update number of trials in Trials popup menu
    trial_strings = cell(1,hdr(2));
    for k = 1:hdr(2)
        trial_strings{k} = num2str(k);
    end
    trials_popuph = findobj( 'Tag', 'popupmenu1' );
    set( trials_popuph, 'String', trial_strings );

    if isempty(ARRVIZ_GLOBAL.trial_data)
        ARRVIZ_GLOBAL.trial_data = zeros( length(t), 16 );
    end

    for k = 1:4
        ARRVIZ_GLOBAL.trial_data(:,k+4) = trials{ARRVIZ_GLOBAL.current_trial}(k:4:end);
    end
    ARRVIZ_GLOBAL.t = t;
end

if ~isempty(ARRVIZ_GLOBAL.MR_datafile)
    [hdr,trials,t] = loadsdtrials( ARRVIZ_GLOBAL.MR_datafile, ARRVIZ_GLOBAL.current_trial );

    if hdr(2) < ARRVIZ_GLOBAL.current_trial
        return % fail silently, return to original state (before attempted data file open)
    end

    % update number of trials in Trials popup menu
    trial_strings = cell(1,hdr(2));
    for k = 1:hdr(2)
        trial_strings{k} = num2str(k);
    end
    trials_popuph = findobj( 'Tag', 'popupmenu1' );
    set( trials_popuph, 'String', trial_strings );

    if isempty(ARRVIZ_GLOBAL.trial_data)
        ARRVIZ_GLOBAL.trial_data = zeros( length(t), 16 );
    end

    for k = 1:4
        ARRVIZ_GLOBAL.trial_data(:,k+8) = trials{ARRVIZ_GLOBAL.current_trial}(k:4:end);
    end
    ARRVIZ_GLOBAL.t = t;
end

if ~isempty(ARRVIZ_GLOBAL.FR_datafile)
    [hdr,trials,t] = loadsdtrials( ARRVIZ_GLOBAL.FR_datafile, ARRVIZ_GLOBAL.current_trial );

    if hdr(2) < ARRVIZ_GLOBAL.current_trial
        return % fail silently
    end

    % update number of trials in Trials popup menu
    trial_strings = cell(1,hdr(2));
    for k = 1:hdr(2)
        trial_strings{k} = num2str(k);
    end
    trials_popuph = findobj( 'Tag', 'popupmenu1' );
    set( trials_popuph, 'String', trial_strings );

    if isempty(ARRVIZ_GLOBAL.trial_data)
        ARRVIZ_GLOBAL.trial_data = zeros( length(t), 16 );
    end

    for k = 1:4
        ARRVIZ_GLOBAL.trial_data(:,k+12) = trials{ARRVIZ_GLOBAL.current_trial}(k:4:end);
    end
    ARRVIZ_GLOBAL.t = t;
end

