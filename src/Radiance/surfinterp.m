function [R] = surfinterp( th, phi, r, TH, PHI, max_dist )
%[R] = surfinterp( th, phi, r, TH, PHI[, max_dist] )
%
% Interpolation is based on a weighted sum of nearby given points. Weights
% are inversely proportional to Euclidean distance (hence, there is a
% nonlinear distortion given that we are working in spherical
% coordinates). Points are only considered if they lie within a particular
% radius (max_dist function argument) of the interpolated coordinate.
%
% Note that the returned variable is a matrix with length(TH) columns
% and length(PHI) rows. It is constructed with the specific intent of being
% used in a call to surf (a Matlab plotting function), where theta is on
% the x-axis.
%
%
% Scott Livingston  <slivingston@caltech.edu>
% June 2010.


% If not given, set a default max radius of consideration
if nargin < 6
    max_dist = 15; % degrees
end

len_PHI = length(PHI);
len_TH = length(TH);
R = zeros(len_PHI,len_TH);

len_r = length(r);

% Buffer of maximum number of considered known points.
% first column is for indices into r, and second column is weight, i.e.
% inverse of distance to (theta,phi) coordinate (to current point-to-be-interpolated).
weights = zeros(length(r),2);

for i = 1:len_PHI
    for j = 1:len_TH
        
        num_weights = 0;
        for k = 1:len_r
            if norm( [TH(j);PHI(i)] - [th(k);phi(k)], 2 ) <= max_dist
                num_weights = num_weights + 1;
                weights(num_weights,1) = k;
                weights(num_weights,2) = 1/norm( [TH(j);PHI(i)] - [th(k);phi(k)], 2 );
            end
        end
        if num_weights == 0
            continue
        end
        
        weight_sum = sum(weights(1:num_weights,2)); % To ensure that applied weights sum to one.
        for k = 1:num_weights
            R(i,j) = R(i,j) + r(weights(k,1))*weights(k,2)/weight_sum;
        end
        
    end
end
