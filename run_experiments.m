% run_experiments.m
% Master runner for the WSN Simulation
clc; clear; close all;

currentDir = fileparts(mfilename('fullpath'));
if isempty(currentDir); currentDir = pwd; end
addpath(fullfile(currentDir, 'simulation'));
addpath(fullfile(currentDir, 'protocols'));
addpath(fullfile(currentDir, 'rl'));
addpath(fullfile(currentDir, 'analysis'));

seeds = [42, 43, 44, 45, 46];
num_runs = length(seeds);
protocols = {'LEACH', 'DEEC', 'PEGASIS', 'RL_Hybrid'};

fprintf('==================================================\n');
fprintf('Starting WSN Experiment (%d runs per protocol)...\n', num_runs);
fprintf('==================================================\n');

res_accum = struct();
for p = 1:length(protocols)
    res_accum.(protocols{p}).alive = [];
    res_accum.(protocols{p}).energy = [];
    res_accum.(protocols{p}).gen = [];
    res_accum.(protocols{p}).del = [];
    res_accum.(protocols{p}).delay = [];
    res_accum.(protocols{p}).r_energy = [];
    res_accum.(protocols{p}).e_std = [];
    res_accum.(protocols{p}).FND = zeros(1, num_runs);
    res_accum.(protocols{p}).HND = zeros(1, num_runs);
    res_accum.(protocols{p}).LND = zeros(1, num_runs);
end

for run_idx = 1:num_runs
    seed = seeds(run_idx);
    fprintf('\n--- Run %d/%d (Seed: %d) ---\n', run_idx, num_runs, seed);
    
    % Generate identical environment mapping and link fading history for this seed
    [wsn_env, lq_history, success_history] = generate_scenario(seed);
    max_rounds = wsn_env.numRounds;
    
    if run_idx == 1
        for p = 1:length(protocols)
            res_accum.(protocols{p}).alive = zeros(num_runs, max_rounds);
            res_accum.(protocols{p}).energy = zeros(num_runs, max_rounds);
            res_accum.(protocols{p}).gen = zeros(num_runs, max_rounds);
            res_accum.(protocols{p}).del = zeros(num_runs, max_rounds);
            res_accum.(protocols{p}).delay = zeros(num_runs, max_rounds);
            res_accum.(protocols{p}).r_energy = zeros(num_runs, max_rounds);
            res_accum.(protocols{p}).e_std = zeros(num_runs, max_rounds);
        end
    end
    
    fprintf('Running LEACH...\n');
    res = LEACH(wsn_env, lq_history, success_history, seed);
    pad_len = max_rounds - length(res.aliveNodes);
    res_accum.LEACH.alive(run_idx, :) = [res.aliveNodes, nan(1, pad_len)];
    res_accum.LEACH.energy(run_idx, :) = [res.totalResidualEnergy, nan(1, pad_len)];
    res_accum.LEACH.gen(run_idx, :) = [res.generatedSourceReports, nan(1, pad_len)];
    res_accum.LEACH.del(run_idx, :) = [res.deliveredSourceReports, nan(1, pad_len)];
    res_accum.LEACH.delay(run_idx, :) = [res.averageEndToEndDelay, nan(1, pad_len)];
    res_accum.LEACH.r_energy(run_idx, :) = [res.routingEnergyConsumedThisRound, nan(1, pad_len)];
    res_accum.LEACH.e_std(run_idx, :) = [res.energyStdDev, nan(1, pad_len)];
    res_accum.LEACH.FND(run_idx) = res.FND; res_accum.LEACH.HND(run_idx) = res.HND; res_accum.LEACH.LND(run_idx) = res.LND;
    
    fprintf('Running DEEC...\n');
    res = DEEC(wsn_env, lq_history, success_history, seed);
    pad_len = max_rounds - length(res.aliveNodes);
    res_accum.DEEC.alive(run_idx, :) = [res.aliveNodes, nan(1, pad_len)];
    res_accum.DEEC.energy(run_idx, :) = [res.totalResidualEnergy, nan(1, pad_len)];
    res_accum.DEEC.gen(run_idx, :) = [res.generatedSourceReports, nan(1, pad_len)];
    res_accum.DEEC.del(run_idx, :) = [res.deliveredSourceReports, nan(1, pad_len)];
    res_accum.DEEC.delay(run_idx, :) = [res.averageEndToEndDelay, nan(1, pad_len)];
    res_accum.DEEC.r_energy(run_idx, :) = [res.routingEnergyConsumedThisRound, nan(1, pad_len)];
    res_accum.DEEC.e_std(run_idx, :) = [res.energyStdDev, nan(1, pad_len)];
    res_accum.DEEC.FND(run_idx) = res.FND; res_accum.DEEC.HND(run_idx) = res.HND; res_accum.DEEC.LND(run_idx) = res.LND;
    
    fprintf('Running PEGASIS...\n');
    res = PEGASIS(wsn_env, lq_history, success_history, seed);
    pad_len = max_rounds - length(res.aliveNodes);
    res_accum.PEGASIS.alive(run_idx, :) = [res.aliveNodes, nan(1, pad_len)];
    res_accum.PEGASIS.energy(run_idx, :) = [res.totalResidualEnergy, nan(1, pad_len)];
    res_accum.PEGASIS.gen(run_idx, :) = [res.generatedSourceReports, nan(1, pad_len)];
    res_accum.PEGASIS.del(run_idx, :) = [res.deliveredSourceReports, nan(1, pad_len)];
    res_accum.PEGASIS.delay(run_idx, :) = [res.averageEndToEndDelay, nan(1, pad_len)];
    res_accum.PEGASIS.r_energy(run_idx, :) = [res.routingEnergyConsumedThisRound, nan(1, pad_len)];
    res_accum.PEGASIS.e_std(run_idx, :) = [res.energyStdDev, nan(1, pad_len)];
    res_accum.PEGASIS.FND(run_idx) = res.FND; res_accum.PEGASIS.HND(run_idx) = res.HND; res_accum.PEGASIS.LND(run_idx) = res.LND;
    
    fprintf('Running RL-HAR...\n');
    res = RL_Hybrid(wsn_env, lq_history, success_history, seed);
    pad_len = max_rounds - length(res.aliveNodes);
    res_accum.RL_Hybrid.alive(run_idx, :) = [res.aliveNodes, nan(1, pad_len)];
    res_accum.RL_Hybrid.energy(run_idx, :) = [res.totalResidualEnergy, nan(1, pad_len)];
    res_accum.RL_Hybrid.gen(run_idx, :) = [res.generatedSourceReports, nan(1, pad_len)];
    res_accum.RL_Hybrid.del(run_idx, :) = [res.deliveredSourceReports, nan(1, pad_len)];
    res_accum.RL_Hybrid.delay(run_idx, :) = [res.averageEndToEndDelay, nan(1, pad_len)];
    res_accum.RL_Hybrid.r_energy(run_idx, :) = [res.routingEnergyConsumedThisRound, nan(1, pad_len)];
    res_accum.RL_Hybrid.e_std(run_idx, :) = [res.energyStdDev, nan(1, pad_len)];
    res_accum.RL_Hybrid.FND(run_idx) = res.FND; res_accum.RL_Hybrid.HND(run_idx) = res.HND; res_accum.RL_Hybrid.LND(run_idx) = res.LND;
end

fprintf('\n==================================================\n');
fprintf('Averaging results and saving files...\n');

analysisDir = fullfile(currentDir, 'analysis');
if ~exist(analysisDir, 'dir'); mkdir(analysisDir); end

% Extract environment template for saving
[wsn_env_template, ~, ~] = generate_scenario(seeds(1));

LEACH_results = struct();
LEACH_results.wsn_env = wsn_env_template;
LEACH_results.configuredRounds = max_rounds; LEACH_results.actualRoundsSimulated = max_rounds;
LEACH_results.aliveNodes = mean(res_accum.LEACH.alive, 1, 'omitnan');
LEACH_results.totalResidualEnergy = mean(res_accum.LEACH.energy, 1, 'omitnan');
LEACH_results.generatedSourceReports = mean(res_accum.LEACH.gen, 1, 'omitnan');
LEACH_results.deliveredSourceReports = mean(res_accum.LEACH.del, 1, 'omitnan');
LEACH_results.sourceReportPDR = LEACH_results.deliveredSourceReports ./ max(1, LEACH_results.generatedSourceReports);
LEACH_results.averageEndToEndDelay = mean(res_accum.LEACH.delay, 1, 'omitnan');
LEACH_results.routingEnergyConsumedThisRound = mean(res_accum.LEACH.r_energy, 1, 'omitnan');
LEACH_results.energyStdDev = mean(res_accum.LEACH.e_std, 1, 'omitnan');
LEACH_results.FND = round(mean(res_accum.LEACH.FND, 'omitnan'));
LEACH_results.HND = round(mean(res_accum.LEACH.HND, 'omitnan'));
LEACH_results.LND = round(mean(res_accum.LEACH.LND, 'omitnan'));
save(fullfile(analysisDir, 'LEACH_results.mat'), 'LEACH_results');

DEEC_results = struct();
DEEC_results.wsn_env = wsn_env_template;
DEEC_results.configuredRounds = max_rounds; DEEC_results.actualRoundsSimulated = max_rounds;
DEEC_results.aliveNodes = mean(res_accum.DEEC.alive, 1, 'omitnan');
DEEC_results.totalResidualEnergy = mean(res_accum.DEEC.energy, 1, 'omitnan');
DEEC_results.generatedSourceReports = mean(res_accum.DEEC.gen, 1, 'omitnan');
DEEC_results.deliveredSourceReports = mean(res_accum.DEEC.del, 1, 'omitnan');
DEEC_results.sourceReportPDR = DEEC_results.deliveredSourceReports ./ max(1, DEEC_results.generatedSourceReports);
DEEC_results.averageEndToEndDelay = mean(res_accum.DEEC.delay, 1, 'omitnan');
DEEC_results.routingEnergyConsumedThisRound = mean(res_accum.DEEC.r_energy, 1, 'omitnan');
DEEC_results.energyStdDev = mean(res_accum.DEEC.e_std, 1, 'omitnan');
DEEC_results.FND = round(mean(res_accum.DEEC.FND, 'omitnan'));
DEEC_results.HND = round(mean(res_accum.DEEC.HND, 'omitnan'));
DEEC_results.LND = round(mean(res_accum.DEEC.LND, 'omitnan'));
save(fullfile(analysisDir, 'DEEC_results.mat'), 'DEEC_results');

PEGASIS_results = struct();
PEGASIS_results.wsn_env = wsn_env_template;
PEGASIS_results.configuredRounds = max_rounds; PEGASIS_results.actualRoundsSimulated = max_rounds;
PEGASIS_results.aliveNodes = mean(res_accum.PEGASIS.alive, 1, 'omitnan');
PEGASIS_results.totalResidualEnergy = mean(res_accum.PEGASIS.energy, 1, 'omitnan');
PEGASIS_results.generatedSourceReports = mean(res_accum.PEGASIS.gen, 1, 'omitnan');
PEGASIS_results.deliveredSourceReports = mean(res_accum.PEGASIS.del, 1, 'omitnan');
PEGASIS_results.sourceReportPDR = PEGASIS_results.deliveredSourceReports ./ max(1, PEGASIS_results.generatedSourceReports);
PEGASIS_results.averageEndToEndDelay = mean(res_accum.PEGASIS.delay, 1, 'omitnan');
PEGASIS_results.routingEnergyConsumedThisRound = mean(res_accum.PEGASIS.r_energy, 1, 'omitnan');
PEGASIS_results.energyStdDev = mean(res_accum.PEGASIS.e_std, 1, 'omitnan');
PEGASIS_results.FND = round(mean(res_accum.PEGASIS.FND, 'omitnan'));
PEGASIS_results.HND = round(mean(res_accum.PEGASIS.HND, 'omitnan'));
PEGASIS_results.LND = round(mean(res_accum.PEGASIS.LND, 'omitnan'));
save(fullfile(analysisDir, 'PEGASIS_results.mat'), 'PEGASIS_results');

RL_HAR_results = struct();
RL_HAR_results.wsn_env = wsn_env_template;
RL_HAR_results.configuredRounds = max_rounds; RL_HAR_results.actualRoundsSimulated = max_rounds;
RL_HAR_results.aliveNodes = mean(res_accum.RL_Hybrid.alive, 1, 'omitnan');
RL_HAR_results.totalResidualEnergy = mean(res_accum.RL_Hybrid.energy, 1, 'omitnan');
RL_HAR_results.generatedSourceReports = mean(res_accum.RL_Hybrid.gen, 1, 'omitnan');
RL_HAR_results.deliveredSourceReports = mean(res_accum.RL_Hybrid.del, 1, 'omitnan');
RL_HAR_results.sourceReportPDR = RL_HAR_results.deliveredSourceReports ./ max(1, RL_HAR_results.generatedSourceReports);
RL_HAR_results.averageEndToEndDelay = mean(res_accum.RL_Hybrid.delay, 1, 'omitnan');
RL_HAR_results.routingEnergyConsumedThisRound = mean(res_accum.RL_Hybrid.r_energy, 1, 'omitnan');
RL_HAR_results.energyStdDev = mean(res_accum.RL_Hybrid.e_std, 1, 'omitnan');
RL_HAR_results.FND = round(mean(res_accum.RL_Hybrid.FND, 'omitnan'));
RL_HAR_results.HND = round(mean(res_accum.RL_Hybrid.HND, 'omitnan'));
RL_HAR_results.LND = round(mean(res_accum.RL_Hybrid.LND, 'omitnan'));
save(fullfile(analysisDir, 'RL_HAR_results.mat'), 'RL_HAR_results');

fprintf('Successfully wrote averaged data to analysis/ directory.\n');
fprintf('Ready for graphing.\n');
