function [F_comp, f, H] = apptrans( samp_period, F, G_trans )
%[F_comp, f, H] = apptrans( samp_period, F, G_trans )
%
% G_trans is a combination of two columns from the G matrix, as created by
% gencomp.m (confer src/analysis/gain_calib in BatStack sourcetree). The
% first column, which contains center-frequency values for the magnitude
% transfer function, and the column corresponding to results for the
% microphone channel on which the given F signal was recorded.
%
% G_trans should have size Nx2, where N is the number of center
% frequencies. The magnitude transfer function is fleshed out by spline
% interpolation (and extrapolation as necessary).
%
%
% Scott Livingston  <slivingston@caltech.edu>
% June 2010.

% Try to be flexible
if size(G_trans,2) > size(G_trans,1)
    G_trans = G_trans';
end

F_comp = fft( F );
f = 1/(2*samp_period)*linspace( 0, 1, length(F_comp)/2+1 );

H = zeros(size(f));
H = interp1( G_trans(:,1), G_trans(:,2), f, 'spline' );

F_comp = 2*abs(F_comp(1:length(f))).*H';
