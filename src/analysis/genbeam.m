function [chan_vects] = genbeam( mike_pos, G, F, t, samp_period, temp, rel_humid, bat_pos, T_start, T_stop, freq_band, voc_num, amode )
%[chan_vects] = genbeam( mike_pos, G, F, t, samp_period, temp, rel_humid, bat_pos, T_start, T_stop, freq_band, voc_num[, amode] )
%
% chan_vects can be visualized, e.g. by plotting with respect to bat
% location at estimated time of vocalization emission.
% Note that a row of NaN (i.e. "not-a-number") in chan_vects indicates a
% mic channel for which no beam could be formed; this should be due to
% missing voc start time on that channel for the requested vocalization.
%
% amode specifies by what method to process signals on each channel, before
% combining to generate a beam. The default is "RMS". Strings are not
% case-sensitive. Recognized modes are
%
%   RMS - find RMS of signals. Note that zero mean noise still has non-zero
%         rms!
%
%   peak - bandpass filter, envelope extract and savitzky-golay filter,
%          followed by peak selection; this should be similar to that used
%          by the 35kHz array (from recording hardware to sunshine
%          analysis).
%
%
% Scott Livingston   <slivingston@caltech.edu
% June 2010.


% Init and parameter-checking
num_mics = size(mike_pos,1);
chan_vects = nan(num_mics,3); % initialize beam matrix

if voc_num < 1 || voc_num > size(T_start,2)
    error( 'Invalid vocalization number, %d, detected.', voc_num );
    return
end
if freq_band(2) < freq_band(1)
    error( 'Invalid requested frequency band: [%.4f, %.4f] Hz', freq_band(1), freq_band(2) );
    return
end

% Determine method of beam calculation
if nargin < 13
    amode = 0; % RMS
else
    if strcmpi(amode,'RMS')
        amode = 0;
    elseif strcmpi(amode,'peak')
        amode = 1;
    else
        fprintf( 'Unrecognized mode string: %s\nAborting.\n', amode );
        chan_vects = [];
        return
    end
end

% Calculate RMS or peaks (depending on mode) for bands,
% Account for spreading loss and atmospheric absorption, and
% Gain compensation
I = find( ~isnan( T_start(:,voc_num) ) );
if isempty(I)
    return % No markings for this vocalization; abort.
end
sig_ext = zeros(size(I));
flight_dist = zeros(size(I));
[b,a] = butter( 3, freq_band*samp_period*2 );
rect = ones(5,1);
for k = 1:length(I)
    
    % Determine indices range to consider, given voc start and stop times
    intv = [min(find(t>= T_start(I(k),voc_num))) max(find(t<= T_stop(I(k),voc_num)))];
    
    % Core
    if amode == 0 % RMS
        tmp_F = filtfilt( b,a, F(intv(1):intv(2),I(k)) );
        sig_ext(k) = sqrt(mean( tmp_F.^2 ));
    else % amode == 1 % peak
        tmp_F = filtfilt( b,a, F(intv(1):intv(2),I(k)) );
        tmp_F = conv(abs(tmp_F),rect);
        tmp_F = sgolayfilt( tmp_F, 3, 23 ); % Order and frame length selected from default values used by Sunshine, as of 28 June 2010.
        sig_ext(k) = max(tmp_F); % Use peak
    end
    
    % prop loss
    flight_dist(k) = norm( bat_pos - mike_pos(I(k),:), 2 );
    sig_ext(k) = get_corrected_intensity( sig_ext(k), flight_dist(k), (freq_band(1)+freq_band(2))/2, temp, rel_humid );
    
    % gain comp
    f = linspace(freq_band(1),freq_band(2),10);
    G_adj = mean( interp1( G(:,1), G(:,I(k)+1), f, 'spline' ) );
    sig_ext(k) = sig_ext(k)*G_adj;
    
end

% Generate scaled vectors, w.r.t. given bat position
for k = 1:length(I)
    chan_vects(I(k),:) = (mike_pos(I(k),:)-bat_pos)/norm(mike_pos(I(k),:)-bat_pos,2)*sig_ext(k);
end


%The below was modified from the get_corrected_intensity function as
%implemented in the sunshine24 (and likely older instances of
%sunshine) code base.
% --Scott Livingston  <slivingston@caltech.edu>, 10 June 2010.
%
% Given the segmented part of the signals (i.e. just the voc) compute the corrected intensity for us and return it
% We need to develop a standalone version of this function too, since we anticipate grabbing data from the database and 
% computing intensity in different ways
%
% From Evans, Bass, Sutherland (full citation?)
function [intensity] = get_corrected_intensity(peak_int, flight_dist, f_c, temp, rh)

p = 101325;
alphaf = alphacalculator(temp,p,rh,f_c);

intensity = zeros(size(peak_int));
for k = 1:length(peak_int)
    %measured_I = max(envelope(samp_start(n):samp_end(n),n).^2);
    atm_atten = 10^((alphaf * flight_dist(k))/10);
    intensity(k) = peak_int(k) * (flight_dist(k)^2) * atm_atten;
end

function [alpha] = alphacalculator(t,p,r,f)

% found from webpage (ISO 9613 - 1Acoustics - Attenuation of sound during propagation outdoors - )
% http://www.measure.demon.co.uk/Acoustics_Software/iso9613.html

t= t+273.15; % convert to kelvin

p=p/101325; % convert to relative pressure

C=4.6151-6.8346* (273.16/t)^(1.261);

h=r*(10^C)*p;        

tr=t/293.15;  % convert to relative air temp (re 20 deg C)

frO=p*(24+4.04e4*h*(0.02+h)/(0.391+h));

frN=p*(tr^(-0.5))*(9+280*h*exp(-4.17*(tr^(-1/3)-1)));

alpha=8.686*f*f*(1.84e-11*(1/p)*sqrt(tr)+...
		(tr^(-2.5))*...
		(0.01275*(exp(-2239.1/t)*1/(frO+f*f/frO))+...
		0.1068*(exp(-3352/t)*1/(frN+f*f/frN))));

%db=1000*alpha;

