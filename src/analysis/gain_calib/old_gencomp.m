function [A_comp] = gencomp( A, gp_ref, target_band )
%

% NOTES: - A_comp is a matrix of size Nx2, where each row is a pair of
%          frequency (1st column) and compensatory (multiplicative)
%          scaling factor needed to make given ``A'' mean freq
%          responses match the reference (or "target") gp_ref.
%
%        - Assumes matrix ``A'' is of the form returned by the
%          avgsweep m-script. For this documentation, let ``A'' have
%          size Nx3.
%
%        - gp_ref is a matrix of size Nx2, where each row is a
%          frequency (first column) and target response (second
%          column) pair.
%
%        - target_band is of the form [MIN_FREQ MAX_FREQ] (in Hz).
%
%        - Currently the script is BLIND TO FREQUENCIES (aside from
%          those ignored due to the specified target_band), i.e., it
%          assumes ``A'' and gp_ref match and only works on a per row
%          basis by comparing entries in the second column of each of
%          these matrices. Accordingly, this m-script is very simple
%          and should be made more general and robust in the future.
%
%
% Scott Livingston
% 3 Dec 2009 (or around midnight on Dec 2...)

% Initialize
A_comp = zeros(size(gp_ref));

% ...and find answer.
A_comp(:,2) = gp_ref(:,2) ./ A(:,2);
A_comp(:,1) = A(:,1);

% And leave elements corresponding to frequencies outside the "target
% band" untouched.
for k = 1:length(A_comp)
    if A_comp(k,1) < target_band(1) || A_comp(k,1) > target_band(2)
        A_comp(k,2) = 1;
    end
end
