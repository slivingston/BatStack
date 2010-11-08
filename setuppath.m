function setuppath( root_path )
%setuppath( root_path )
%
% Setup path for doing stuff in Octave or Matlab. If no path to the
% main BatStack source tree is given, then use pwd (i.e. ``present
% working directory'').
%
% Scott Livingston
% 7 Nov 2010

if nargin < 1
    root_path = pwd;
end

addpath([root_path '/src/Radiance']);
addpath([root_path '/src/analysis']);
addpath([root_path '/src/analysis/gain_calib']);
