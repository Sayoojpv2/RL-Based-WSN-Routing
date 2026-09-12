% run_full_evaluation.m
% Master Evaluation Script for 5-Seed WSN Experiment
% Compares LEACH, DEEC, PEGASIS, and RL-HAR v2

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

fprintf('====================================================================\n');
fprintf('  STARTING FULL 5-SEED EXPERIMENT (Seeds: 42, 43, 44, 45, 46)\n');
fprintf('====================================================================\n');

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

% Detailed per-run data containers
max_rounds = 1000;
for p = 1:length(protocols)
    res_accum.(protocols{p}).alive = zeros(num_runs, max_rounds);
    res_accum.(protocols{p}).energy = zeros(num_runs, max_rounds);
    res_accum.(protocols{p}).gen = zeros(num_runs, max_rounds);
    res_accum.(protocols{p}).del = zeros(num_runs, max_rounds);
    res_accum.(protocols{p}).delay = zeros(num_runs, max_rounds);
    res_accum.(protocols{p}).r_energy = zeros(num_runs, max_rounds);
    res_accum.(protocols{p}).e_std = zeros(num_runs, max_rounds);
end

for run_idx = 1:num_runs
    seed = seeds(run_idx);
    fprintf('\n------------------------------------------------------------\n');
    fprintf('  RUN %d/%d (Seed: %d)\n', run_idx, num_runs, seed);
    fprintf('------------------------------------------------------------\n');
    
    [wsn_env, lq_history, success_history] = generate_scenario(seed);
    
    % 1. LEACH
    fprintf('Running LEACH...\n');
    res_l = LEACH(wsn_env, lq_history, success_history, seed);
    pad_len = max_rounds - length(res_l.aliveNodes);
    res_accum.LEACH.alive(run_idx, :) = [res_l.aliveNodes, nan(1, pad_len)];
    res_accum.LEACH.energy(run_idx, :) = [res_l.totalResidualEnergy, nan(1, pad_len)];
    res_accum.LEACH.gen(run_idx, :) = [res_l.generatedSourceReports, nan(1, pad_len)];
    res_accum.LEACH.del(run_idx, :) = [res_l.deliveredSourceReports, nan(1, pad_len)];
    res_accum.LEACH.delay(run_idx, :) = [res_l.averageEndToEndDelay, nan(1, pad_len)];
    res_accum.LEACH.r_energy(run_idx, :) = [res_l.routingEnergyConsumedThisRound, nan(1, pad_len)];
    res_accum.LEACH.e_std(run_idx, :) = [res_l.energyStdDev, nan(1, pad_len)];
    res_accum.LEACH.FND(run_idx) = res_l.FND; res_accum.LEACH.HND(run_idx) = res_l.HND; res_accum.LEACH.LND(run_idx) = res_l.LND;
    
    % 2. DEEC
    fprintf('Running DEEC...\n');
    res_d = DEEC(wsn_env, lq_history, success_history, seed);
    pad_len = max_rounds - length(res_d.aliveNodes);
    res_accum.DEEC.alive(run_idx, :) = [res_d.aliveNodes, nan(1, pad_len)];
    res_accum.DEEC.energy(run_idx, :) = [res_d.totalResidualEnergy, nan(1, pad_len)];
    res_accum.DEEC.gen(run_idx, :) = [res_d.generatedSourceReports, nan(1, pad_len)];
    res_accum.DEEC.del(run_idx, :) = [res_d.deliveredSourceReports, nan(1, pad_len)];
    res_accum.DEEC.delay(run_idx, :) = [res_d.averageEndToEndDelay, nan(1, pad_len)];
    res_accum.DEEC.r_energy(run_idx, :) = [res_d.routingEnergyConsumedThisRound, nan(1, pad_len)];
    res_accum.DEEC.e_std(run_idx, :) = [res_d.energyStdDev, nan(1, pad_len)];
    res_accum.DEEC.FND(run_idx) = res_d.FND; res_accum.DEEC.HND(run_idx) = res_d.HND; res_accum.DEEC.LND(run_idx) = res_d.LND;
    
    % 3. PEGASIS
    fprintf('Running PEGASIS...\n');
    res_p = PEGASIS(wsn_env, lq_history, success_history, seed);
    pad_len = max_rounds - length(res_p.aliveNodes);
    res_accum.PEGASIS.alive(run_idx, :) = [res_p.aliveNodes, nan(1, pad_len)];
    res_accum.PEGASIS.energy(run_idx, :) = [res_p.totalResidualEnergy, nan(1, pad_len)];
    res_accum.PEGASIS.gen(run_idx, :) = [res_p.generatedSourceReports, nan(1, pad_len)];
    res_accum.PEGASIS.del(run_idx, :) = [res_p.deliveredSourceReports, nan(1, pad_len)];
    res_accum.PEGASIS.delay(run_idx, :) = [res_p.averageEndToEndDelay, nan(1, pad_len)];
    res_accum.PEGASIS.r_energy(run_idx, :) = [res_p.routingEnergyConsumedThisRound, nan(1, pad_len)];
    res_accum.PEGASIS.e_std(run_idx, :) = [res_p.energyStdDev, nan(1, pad_len)];
    res_accum.PEGASIS.FND(run_idx) = res_p.FND; res_accum.PEGASIS.HND(run_idx) = res_p.HND; res_accum.PEGASIS.LND(run_idx) = res_p.LND;
    
    % 4. RL-HAR
    fprintf('Running RL-HAR...\n');
    res_rl = RL_Hybrid(wsn_env, lq_history, success_history, seed);
    pad_len = max_rounds - length(res_rl.aliveNodes);
    res_accum.RL_Hybrid.alive(run_idx, :) = [res_rl.aliveNodes, nan(1, pad_len)];
    res_accum.RL_Hybrid.energy(run_idx, :) = [res_rl.totalResidualEnergy, nan(1, pad_len)];
    res_accum.RL_Hybrid.gen(run_idx, :) = [res_rl.generatedSourceReports, nan(1, pad_len)];
    res_accum.RL_Hybrid.del(run_idx, :) = [res_rl.deliveredSourceReports, nan(1, pad_len)];
    res_accum.RL_Hybrid.delay(run_idx, :) = [res_rl.averageEndToEndDelay, nan(1, pad_len)];
    res_accum.RL_Hybrid.r_energy(run_idx, :) = [res_rl.routingEnergyConsumedThisRound, nan(1, pad_len)];
    res_accum.RL_Hybrid.e_std(run_idx, :) = [res_rl.energyStdDev, nan(1, pad_len)];
    res_accum.RL_Hybrid.FND(run_idx) = res_rl.FND; res_accum.RL_Hybrid.HND(run_idx) = res_rl.HND; res_accum.RL_Hybrid.LND(run_idx) = res_rl.LND;
end

% Save standard MAT files
analysisDir = fullfile(currentDir, 'analysis');
if ~exist(analysisDir, 'dir'); mkdir(analysisDir); end
[wsn_env_template, ~, ~] = generate_scenario(seeds(1));

for p = 1:length(protocols)
    prot = protocols{p};
    save_name = prot;
    if strcmp(prot, 'RL_Hybrid'); save_name = 'RL_HAR'; end
    
    res_struct = struct();
    res_struct.wsn_env = wsn_env_template;
    res_struct.configuredRounds = max_rounds;
    res_struct.actualRoundsSimulated = max_rounds;
    res_struct.aliveNodes = mean(res_accum.(prot).alive, 1, 'omitnan');
    res_struct.totalResidualEnergy = mean(res_accum.(prot).energy, 1, 'omitnan');
    res_struct.generatedSourceReports = mean(res_accum.(prot).gen, 1, 'omitnan');
    res_struct.deliveredSourceReports = mean(res_accum.(prot).del, 1, 'omitnan');
    res_struct.sourceReportPDR = res_struct.deliveredSourceReports ./ max(1, res_struct.generatedSourceReports);
    res_struct.averageEndToEndDelay = mean(res_accum.(prot).delay, 1, 'omitnan');
    res_struct.routingEnergyConsumedThisRound = mean(res_accum.(prot).r_energy, 1, 'omitnan');
    res_struct.energyStdDev = mean(res_accum.(prot).e_std, 1, 'omitnan');
    res_struct.FND = round(mean(res_accum.(prot).FND, 'omitnan'));
    res_struct.HND = round(mean(res_accum.(prot).HND, 'omitnan'));
    res_struct.LND = round(mean(res_accum.(prot).LND, 'omitnan'));
    protoDir = fullfile(currentDir, 'results', 'protocol_results');
    if ~exist(protoDir, 'dir'); mkdir(protoDir); end
    eval([save_name, '_results = res_struct;']);
    save(fullfile(protoDir, [save_name, '_results.mat']), [save_name, '_results'], '-v7');
end
rawDir = fullfile(currentDir, 'results', 'raw');
if ~exist(rawDir, 'dir'); mkdir(rawDir); end
save(fullfile(rawDir, 'all_runs_raw.mat'), 'res_accum', '-v7');

% =========================================================================
% COMPUTE METRICS ACROSS ALL ROUNDS AND PER PERIOD
% =========================================================================

periods = {'Full (1-1000)', 'Pre-Failure (1-499)', 'Failure Region (500)', 'Post-Failure (501-1000)'};
ranges = {1:1000, 1:499, 500:500, 501:1000};

fprintf('\n====================================================================\n');
fprintf('  5-SEED AVERAGED RESULTS - NUMERICAL SUMMARY\n');
fprintf('====================================================================\n');

prot_labels = {'LEACH', 'DEEC', 'PEGASIS', 'RL-Hybrid'};
prot_keys = {'LEACH', 'DEEC', 'PEGASIS', 'RL_Hybrid'};

metrics_table = struct();

for p = 1:length(protocols)
    pk = prot_keys{p};
    pl = prot_labels{p};
    
    m_alive = res_accum.(pk).alive;
    m_energy = res_accum.(pk).energy;
    m_gen = res_accum.(pk).gen;
    m_del = res_accum.(pk).del;
    m_delay = res_accum.(pk).delay;
    m_reng = res_accum.(pk).r_energy;
    m_estd = res_accum.(pk).e_std;
    
    fnd_val = mean(res_accum.(pk).FND, 'omitnan');
    hnd_val = mean(res_accum.(pk).HND, 'omitnan');
    lnd_val = mean(res_accum.(pk).LND, 'omitnan');
    
    fprintf('\n>>> %s <<<\n', pl);
    fprintf('  Lifetime: FND=%.1f | HND=%.1f | LND=%.1f\n', fnd_val, hnd_val, lnd_val);
    
    for pr = 1:length(periods)
        idx = ranges{pr};
        
        gen_sub = sum(m_gen(:, idx), 2);
        del_sub = sum(m_del(:, idx), 2);
        reng_sub = sum(m_reng(:, idx), 2);
        
        mean_gen = mean(gen_sub);
        mean_del = mean(del_sub);
        mean_pdr = mean(del_sub ./ max(1, gen_sub)) * 100;
        mean_loss = 100 - mean_pdr;
        mean_reng = mean(reng_sub);
        
        if mean_del > 0
            e_per_rep = mean_reng / mean_del;
            e_eff = mean_del / mean_reng;
        else
            e_per_rep = NaN;
            e_eff = 0;
        end
        
        delay_vals = m_delay(:, idx);
        mean_delay = mean(delay_vals(:), 'omitnan');
        
        alive_end = mean(m_alive(:, idx(end)), 'omitnan');
        e_res_avg = mean(m_energy(:, idx(end)), 'omitnan');
        e_std_avg = mean(m_estd(:, idx), 'all', 'omitnan');
        
        % Throughput: delivered reports per round
        tput = mean_del / length(idx);
        
        metrics_table.(pk).(sprintf('period_%d', pr)).del = mean_del;
        metrics_table.(pk).(sprintf('period_%d', pr)).gen = mean_gen;
        metrics_table.(pk).(sprintf('period_%d', pr)).pdr = mean_pdr;
        metrics_table.(pk).(sprintf('period_%d', pr)).loss = mean_loss;
        metrics_table.(pk).(sprintf('period_%d', pr)).reng = mean_reng;
        metrics_table.(pk).(sprintf('period_%d', pr)).e_per_rep = e_per_rep;
        metrics_table.(pk).(sprintf('period_%d', pr)).e_eff = e_eff;
        metrics_table.(pk).(sprintf('period_%d', pr)).delay = mean_delay;
        metrics_table.(pk).(sprintf('period_%d', pr)).alive_end = alive_end;
        metrics_table.(pk).(sprintf('period_%d', pr)).e_res = e_res_avg;
        metrics_table.(pk).(sprintf('period_%d', pr)).e_std = e_std_avg;
        metrics_table.(pk).(sprintf('period_%d', pr)).tput = tput;
        
        fprintf('  Period: %-26s | AliveEnd: %4.1f | PDR: %5.2f%% | Del: %6.0f | Energy: %6.2f J | E/Del: %.6f J | Eff: %6.1f | Delay: %.4f s | Tput: %.2f rep/rnd\n', ...
            periods{pr}, alive_end, mean_pdr, mean_del, mean_reng, e_per_rep, e_eff, mean_delay, tput);
    end
end

% =========================================================================
% DIRECT COMPARISON: RL-Hybrid vs LEACH, DEEC, PEGASIS
% =========================================================================

fprintf('\n====================================================================\n');
fprintf('  DIRECT COMPARISON: RL-Hybrid vs LEACH / DEEC / PEGASIS (Full 1000 Rounds)\n');
fprintf('====================================================================\n');

comp_metrics = {'FND', 'HND', 'LND', 'Final Alive Nodes', 'Avg Residual Energy (J)', ...
                'PDR (%)', 'Packet Loss (%)', 'Delivered Reports', ...
                'Total Routing Energy (J)', 'Energy / Delivered Report (J)', ...
                'Energy Efficiency (reports/J)', 'Avg Delay (s)', 'Throughput (rep/rnd)'};

rl_fnd = mean(res_accum.RL_Hybrid.FND, 'omitnan');
rl_hnd = mean(res_accum.RL_Hybrid.HND, 'omitnan');
rl_lnd = mean(res_accum.RL_Hybrid.LND, 'omitnan');
rl_full = metrics_table.RL_Hybrid.period_1;

baselines = {'LEACH', 'DEEC', 'PEGASIS'};
base_labels = {'LEACH', 'DEEC', 'PEGASIS'};

for b = 1:length(baselines)
    bk = baselines{b};
    bl = base_labels{b};
    b_full = metrics_table.(bk).period_1;
    b_fnd = mean(res_accum.(bk).FND, 'omitnan');
    b_hnd = mean(res_accum.(bk).HND, 'omitnan');
    b_lnd = mean(res_accum.(bk).LND, 'omitnan');
    
    fprintf('\n------------------------------------------------------------\n');
    fprintf('  RL-Hybrid vs %s\n', bl);
    fprintf('------------------------------------------------------------\n');
    fprintf('%-32s | %-12s | %-12s | %s\n', 'Metric', 'RL-Hybrid', bl, 'Verdict');
    fprintf('--------------------------------------------------------------------\n');
    
    % FND (Higher is better)
    verdict = 'Equal';
    if rl_fnd > b_fnd; verdict = 'Better'; elseif rl_fnd < b_fnd; verdict = 'Worse'; end
    fprintf('%-32s | %-12.1f | %-12.1f | %s\n', 'FND (rounds)', rl_fnd, b_fnd, verdict);
    
    % HND (Higher is better)
    verdict = 'Equal';
    if isnan(b_hnd) && ~isnan(rl_hnd); verdict = 'Worse';
    elseif ~isnan(b_hnd) && isnan(rl_hnd); verdict = 'Better';
    elseif rl_hnd > b_hnd; verdict = 'Better'; elseif rl_hnd < b_hnd; verdict = 'Worse'; end
    fprintf('%-32s | %-12.1f | %-12.1f | %s\n', 'HND (rounds)', rl_hnd, b_hnd, verdict);
    
    % LND (Higher is better)
    verdict = 'Equal';
    if isnan(b_lnd) && ~isnan(rl_lnd); verdict = 'Worse';
    elseif ~isnan(b_lnd) && isnan(rl_lnd); verdict = 'Better';
    elseif rl_lnd > b_lnd; verdict = 'Better'; elseif rl_lnd < b_lnd; verdict = 'Worse'; end
    fprintf('%-32s | %-12.1f | %-12.1f | %s\n', 'LND (rounds)', rl_lnd, b_lnd, verdict);
    
    % Final Alive Nodes (Higher is better)
    verdict = 'Equal';
    if rl_full.alive_end > b_full.alive_end; verdict = 'Better';
    elseif rl_full.alive_end < b_full.alive_end; verdict = 'Worse'; end
    fprintf('%-32s | %-12.1f | %-12.1f | %s\n', 'Final Alive Nodes', rl_full.alive_end, b_full.alive_end, verdict);
    
    % PDR (Higher is better)
    verdict = 'Equal';
    if rl_full.pdr > b_full.pdr; verdict = 'Better';
    elseif rl_full.pdr < b_full.pdr; verdict = 'Worse'; end
    fprintf('%-32s | %-11.2f%% | %-11.2f%% | %s\n', 'PDR', rl_full.pdr, b_full.pdr, verdict);
    
    % Packet Loss (Lower is better)
    verdict = 'Equal';
    if rl_full.loss < b_full.loss; verdict = 'Better';
    elseif rl_full.loss > b_full.loss; verdict = 'Worse'; end
    fprintf('%-32s | %-11.2f%% | %-11.2f%% | %s\n', 'Packet Loss', rl_full.loss, b_full.loss, verdict);
    
    % Delivered Reports (Higher is better)
    verdict = 'Equal';
    if rl_full.del > b_full.del; verdict = 'Better';
    elseif rl_full.del < b_full.del; verdict = 'Worse'; end
    fprintf('%-32s | %-12.0f | %-12.0f | %s\n', 'Delivered Reports', rl_full.del, b_full.del, verdict);
    
    % Total Routing Energy (Lower is better for same work, but higher efficiency matters)
    fprintf('%-32s | %-12.2f | %-12.2f | %s\n', 'Total Routing Energy (J)', rl_full.reng, b_full.reng, '-');
    
    % Energy / Delivered Report (Lower is better)
    verdict = 'Equal';
    if rl_full.e_per_rep < b_full.e_per_rep; verdict = 'Better';
    elseif rl_full.e_per_rep > b_full.e_per_rep; verdict = 'Worse'; end
    fprintf('%-32s | %-12.6f | %-12.6f | %s\n', 'Energy / Delivered Report (J)', rl_full.e_per_rep, b_full.e_per_rep, verdict);
    
    % Energy Efficiency (Higher is better)
    verdict = 'Equal';
    if rl_full.e_eff > b_full.e_eff; verdict = 'Better';
    elseif rl_full.e_eff < b_full.e_eff; verdict = 'Worse'; end
    fprintf('%-32s | %-12.1f | %-12.1f | %s\n', 'Energy Efficiency (reports/J)', rl_full.e_eff, b_full.e_eff, verdict);
    
    % Delay (Lower is better)
    verdict = 'Equal';
    if rl_full.delay < b_full.delay; verdict = 'Better';
    elseif rl_full.delay > b_full.delay; verdict = 'Worse'; end
    fprintf('%-32s | %-12.4f | %-12.4f | %s\n', 'Avg End-to-End Delay (s)', rl_full.delay, b_full.delay, verdict);
    
    % Throughput (Higher is better)
    verdict = 'Equal';
    if rl_full.tput > b_full.tput; verdict = 'Better';
    elseif rl_full.tput < b_full.tput; verdict = 'Worse'; end
    fprintf('%-32s | %-12.2f | %-12.2f | %s\n', 'Throughput (rep/round)', rl_full.tput, b_full.tput, verdict);
end

fprintf('\n====================================================================\n');
fprintf('  EXPERIMENT COMPLETE AND VERIFIED.\n');
fprintf('====================================================================\n');

