
function isVisible = visibility_check(AIR_ecef, SAT_ecef, mask_angle_deg)
%==========================================================================
% SATERA - Satellite-to-Aircraft Visibility Check
%==========================================================================
%
%   isVisible = visibility_check(AIR_ecef, SAT_ecef, mask_angle_deg)
%
%   Determines line-of-sight visibility between each aircraft and each
%   satellite based on elevation angle above local horizon.
%
%   INPUTS:
%       AIR_ecef        - [N_t x 3] aircraft positions (ECEF, m)
%       SAT_ecef        - [3 x N_t x N_sat] satellite positions (ECEF, m)
%       mask_angle_deg  - scalar, minimum elevation angle [deg]
%
%   OUTPUTS:
%       isVisible       - [N_sat x N_t] logical visibility matrix
%
%==========================================================================



if nargin < 3
    mask_angle_deg = 1; % default mask angle
end

N_t = size(AIR_ecef, 1);
[dim1, Nt_s, N_sat] = size(SAT_ecef);

if dim1 ~= 3
    error('SAT_ecef must be [3 x N_t x N_sat]');
end
if Nt_s ~= N_t
    error('AIR_ecef and SAT_ecef must have same number of time steps.');
end

isVisible = false(N_sat, N_t);
%elev_deg  = zeros(N_sat, N_t);

for kt = 1:N_t
    r_air = AIR_ecef(kt, :);               % [1x3]
    r_sat = squeeze(SAT_ecef(:, kt, :))';  % [N_sat x 3]
   
    % Local zenith unit vector at aircraft
    zenit_vec = r_air / norm(r_air); % 1x3

    % Line-of-sight unit vectors
    d = r_sat - r_air; % Nx3
    d_unit = d ./ vecnorm(d, 2, 2);

    % Elevation angle in degrees
    cos_theta = dot(d_unit, repmat(zenit_vec, N_sat, 1), 2);
    elev = asind(cos_theta);

    % Apply mask
    isVisible(:, kt) = elev >= mask_angle_deg;
    %elev_deg(:, kt)  = elev;
end

end

