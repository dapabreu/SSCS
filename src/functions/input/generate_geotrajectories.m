clear;
clc;
load("ground_truth_resampled.mat")
max_idx = size(ground_truth_resampled, 2);
seq = randperm(max_idx);
total_planes = 4;
planes_geo_traj = cell(1, total_planes);
all_pos = {ground_truth_resampled.pos_ecef};
all_t = {ground_truth_resampled.t};
for p = 1:total_planes
    idx = p; % seq(1 + rem(p - 1, max_idx));
    pos = all_pos{idx};
    t = all_t{idx};
    offset = 0; % (rand - 0.5) * 200;
    waypoints = ecef2lla([pos(:, 1) + offset, pos(:, 2) + offset, pos(:, 3) + offset]);
    times = seconds(t - t(1));
    planes_geo_traj{p} = geoTrajectory(waypoints, times);
end
save("planes_geo_traj_4.mat", "planes_geo_traj", "-v7.3");