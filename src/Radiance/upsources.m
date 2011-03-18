function upsources( new_paths, target_dir )
%upsources( new_paths, target_dir )
%
% (Batch) update file sources listed in Radiance analysis files.  More
% explicitly, load the radiance_analysed structure from each file with
% name ending in *_rad.mat (following the convention; confer the
% BatStack tech manual) in the specified directory target_dir, and
% update paths as specified from given new_paths (while keeping
% relative file names fixed).  If target_dir is not given, then search
% in current directory.
%
% N.B., we assume files conforming to specification Version 1.  Hence,
% new_paths is a structure with field names matching those contained
% in radiance_analysed for which it makes sense to ``change the
% path''. 
%
% If new_paths is a string, then it is regarded as the new path for
% everything.
%
%
% Scott Livingston
% Nov 2010, Mar 2011.

if nargin < 2
    target_dir = pwd;
end

D = dir([target_dir '/*_rad.mat']);
if isempty(D)
    fprintf( 'No Radiance analysis files found in %s\n', target_dir );
    return
end

if ischar(new_paths)
    new_path_str = new_paths;
    clear new_paths
    new_paths.d3_file = new_path_str;
    new_paths.wamike_file = new_path_str;
    new_paths.wagaincal_file = new_path_str;
    new_paths.data_file = new_path_str;
end

for k = 1:length(D)
    fprintf( 'Updating %s ...\n', D(k).name );
    load( [target_dir '/' D(k).name] );

    radiance_analysed.version = 1; % force it to v1 (MUST CHANGE THIS SOON!)
    
    ind = get_last_ind(radiance_analysed.d3_file);
    if ~isempty(ind)
        radiance_analysed.d3_file = [new_paths.d3_file '/' radiance_analysed.d3_file(ind+1:end)];
    end

    ind = get_last_ind(radiance_analysed.wamike_file);
    if ~isempty(ind)
        radiance_analysed.wamike_file = [new_paths.wamike_file '/' radiance_analysed.wamike_file(ind+1:end)];
    end

    ind = get_last_ind(radiance_analysed.wagaincal_file);
    if ~isempty(ind)
        radiance_analysed.wagaincal_file = [new_paths.wagaincal_file '/' radiance_analysed.wagaincal_file(ind+1:end)];
    end

    ind = get_last_ind(radiance_analysed.data_file);
    if ~isempty(ind)
        radiance_analysed.data_file = [new_paths.data_file '/' radiance_analysed.data_file(ind+1:end)];
    end

    save('-V7', [target_dir '/' D(k).name], 'radiance_analysed');

end


function ind = get_last_ind( fname )
ind = strfind(fname, '/');
if isempty(ind)
    ind = strfind(fname, '\'); % hat tip to Windows
    if isempty(ind)
        ind = [];
        return
    end
end
ind = ind(end);
return
