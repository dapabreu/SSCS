function PrecompData = satellite_constellation(cfg)
%==========================================================================
% SATERA - Generate and Precompute Satellite Constellation States (SGP4)
%==========================================================================
%
%   PrecompData = satellite_constellation(cfg)
%
%   Generates a Walker constellation in a satelliteScenario object and
%   precomputes satellite positions and velocities in ECEF coordinates.
%
%   INPUT (cfg structure fields):
%       .startTime        - datetime, start of scenario
%       .duration_hours   - scalar, duration of scenario in hours
%       .sampleTime       - scalar [s], time step for propagation
%       .altitude_m       - orbital altitude above Earth [m]
%       .inclination_deg  - orbital inclination [deg]
%       .totalSatellites  - total number of satellites
%       .numPlanes        - number of orbital planes
%       .phasing          - Walker phasing (usually 0)
%       .doPlot           - (optional) true/false to visualize scenario
%       .outputFile       - (optional) filename for .mat output
%
%   OUTPUT:
%       PrecompData struct with fields:
%           .t0          -> start time (datetime)
%           .t_vec_s     -> vector of simulation times [s]
%           .pos_all     -> [3 x Nsat x Nt] ECEF positions [m]
%           .vel_all     -> [3 x Nsat x Nt] ECEF velocities [m/s]
%           .dt          -> sampling period [s]
%
%   Example:
%       cfg = struct('startTime', datetime(2025,10,21,10,0,0), ...
%                    'duration_hours', 7.5, ...
%                    'sampleTime', 5, ...
%                    'altitude_m', 500e3, ...
%                    'inclination_deg', 86, ...
%                    'totalSatellites', 200, ...
%                    'numPlanes', 10, ...
%                    'phasing', 0, ...
%                    'doPlot', true);
%       PrecompData = satellite_constellation(cfg);
%
%==========================================================================

% Ejemplo:
% cfg = struct('startTime', datetime(2025,10,21,10,0,0), ...
%              'duration_seconds', 3600, ...
%              'sampleTime', 1, ...
%              'altitude_m', 500e3, ...
%              'inclination_deg', 86, ...
%              'totalSatellites', 200, ...
%              'numPlanes', 10, ...
%              'phasing', 0, ...
%              'doPlot', false);
% 
% PrecompData = satellite_constellation(cfg);


%% --- Input checks -------------------------------------------------------
if nargin < 1
    error('Configuration structure (cfg) is required.');
end
if ~isfield(cfg, 'sim') || ~isfield(cfg.sim,'start_time_utc'), cfg.sim.start_time_utc = datetime('now'); end
if ~isfield(cfg, 'sim') || ~isfield(cfg.sim,'start_time_utc') , cfg.sim.stop_time_utc = cfg.sim.start_time_utc + seconds(3600); end
if ~isfield(cfg, 'sim') || ~isfield(cfg.sim,'dt'), cfg.sim.dt = 1.0; end
if ~isfield(cfg, 'sat') || ~isfield(cfg.sat, 'alt_km'), cfg.sat.alt_km = 500e3; end
if ~isfield(cfg, 'sat') || ~isfield(cfg.sat, 'inclination_deg'), cfg.sat.inclination_deg = 86; end
if ~isfield(cfg, 'sat') || ~isfield(cfg.sat, 'num_sats'), cfg.sat.num_sats = 200; end
if ~isfield(cfg, 'sat') || ~isfield(cfg.sat, 'numPlanes'), cfg.sat.planes = 10; end
if ~isfield(cfg, 'sat') || ~isfield(cfg.sat, 'phasing'), cfg.sat.phasing = 0; end
if ~isfield(cfg, 'sat') || ~isfield(cfg.sat, 'orbit_prop'), cfg.sat.orbit_prop = 'sgp4'; end 
if ~isfield(cfg, 'sat') || ~isfield(cfg.sat, 'constellation_type'), cfg.sat.constellation_type = 'walkerStar';end
if ~isfield(cfg, 'doPlot'), cfg.doPlot = true; end
% if ~isfield(cfg, 'outputFile'), cfg.outputFile = 'PrecomputedConstellation.mat'; end

%% --- Scenario definition ------------------------------------------------
fprintf('\n=== Generating satellite constellation ===\n');
startTime = cfg.sim.start_time_utc;
stopTime  = cfg.sim.stop_time_utc;
sampleTime = cfg.sim.dt;

sc = satelliteScenario(startTime, stopTime, sampleTime);

%% --- Define orbit parameters -------------------------------------------
earth_radius_m = 6371e3;
radius = earth_radius_m + 1000*cfg.sat.alt_km;

fprintf('Creating Walker constellation (SGP4)...\n');

if (strcmp(cfg.sat.constellation_type, 'walkerStar'))
Satellites = walkerStar(sc, radius, cfg.sat.inclination_deg, ...
                        cfg.sat.num_sats, cfg.sat.planes, ...
                        cfg.sat.phasing, ...
                        "OrbitPropagator", "sgp4", ...
                        "Name", "SATERA_LEO");
elseif (strcmp(cfg.sat.constellation_type, 'walkerDelta'))
 Satellites = walkerDelta(sc, radius, cfg.sat.inclination_deg, ...
                        cfg.sat.num_sats, cfg.sat.planes, ...
                        cfg.sat.phasing, ...
                        "OrbitPropagator", "sgp4", ...
                        "Name", "SATERA_LEO");
else
    error('Wrong name for constelation type. Check senacrio_config.');
end

pointAt(Satellites,'nadir') % 'nadir' is the default pointing direction.

fprintf('  → %d satellites, %d planes, altitude %.0f km\n', ...
        cfg.sat.num_sats, cfg.sat.planes, cfg.sat.alt_km);

%% --- Time vector for propagation ---------------------------------------
t0 = sc.StartTime;
tf = sc.StopTime;
t_vec = t0:seconds(sampleTime):tf;
t_vec_s = seconds(t_vec - t0);

%% --- Propagate satellite states ----------------------------------------
fprintf('Propagating satellite states (ECEF)...\n');
[pos_all, vel_all] = states(Satellites, "CoordinateFrame", "ecef");
fprintf('Propagation completed.\n');

%% --- Store data --------------------------------------------------------
PrecompData.t0 = t0;
PrecompData.t_vec_s = t_vec_s;
PrecompData.pos_all = pos_all;
PrecompData.vel_all = vel_all;
PrecompData.dt = sampleTime;

% save(cfg.sat.outputFile, 'PrecompData', '-v7.3');
% fprintf('Saved precomputed data to "%s".\n', cfg.sat.outputFile);

%% --- Optional visualization --------------------------------------------
if cfg.sat.doPlot
    fprintf('Opening visualization window...\n');
    Satellites(1).Visual3DModel = "SmallSat.glb";
    % Create the scenario viewer without showing details
    viewer = satelliteScenarioViewer(sc, 'ShowDetails', false);
    % Show the orbits of the satellites
    show([Satellites.Orbit]);
    camtarget(viewer, Satellites(1));

end

fprintf('=== Constellation generation complete ===\n\n');
end
