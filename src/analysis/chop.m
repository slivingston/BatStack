%[F_sub, F_filt, t_sub] = chop( F, t, intv, freq_band, Ts[, gc] )
%
% Scott Livingston
% June 2010.
function [F_sub, F_filt, t_sub] = chop( F, t, intv, freq_band, Ts, gc )

if nargin < 6
    gc = 1:size(F,2);
end

xl = [min(find(t >= intv(1) )) max(find(t<= intv(2) ))];

wlen = 5;

F_sub = zeros(diff(xl)+1,16); F_sub = F(xl(1):xl(2),:);
t_sub = t(xl(1):xl(2));
F_filt = zeros(size(F_sub));

[b,a] = butter( 3, freq_band*Ts*2 );
for k = 1:length(gc)
    F_filt(:,gc(k)) = filtfilt(b,a, F_sub(:,gc(k)) );
    x = conv(F_filt(:,gc(k)).^2,ones(wlen,1));
    F_filt(:,gc(k)) = x(ceil(wlen/2):end-floor(wlen/2));
end
