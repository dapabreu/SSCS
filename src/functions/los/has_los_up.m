function los = has_los_up(p_pos, s_pos, min_elev)
% Description: Calculates LoS for uplinks.
% Arguments:
%   p_pos: Nx3 ECEF positions of planes.
%   s_pos: Mx3 ECEF positions of satellites.
%   min_elev: Minimum elevation for LoS.
% Returns:
%   los: NxM logical matrix.
    
    % Expand both to NxMx3 with implicit expansion:
    p_v = reshape(p_pos, [], 1, 3);  % Nx1x3
    s_v = reshape(s_pos, 1, [], 3);  % 1xMx3
    v = s_v - p_v;  % NxMx3
    
    % Auxiliary values:
    dot_v = sum(v .* p_v, 3);  % NxM
    dist_v = sqrt(sum(v .^2, 3));  % NxM
    norm_v = sqrt(sum(p_v .^ 2, 3));  % Nx1 -> NxM via expansion
    
    % Gets final LoS matrix:
    los = (dot_v ./ (dist_v .* norm_v)) > cosd(90 - min_elev);
end