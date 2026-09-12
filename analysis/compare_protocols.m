clc;
close all;

% =========================================================
% FIND PROJECT / ANALYSIS FOLDER
% =========================================================

projectRoot = fileparts(fileparts(mfilename('fullpath')));
if isempty(projectRoot); projectRoot = pwd; end

protoDir = fullfile(projectRoot, 'results', 'protocol_results');
if ~exist(protoDir, 'dir')
    protoDir = fullfile(projectRoot, 'analysis');
end

% =========================================================
% LOAD ACTUAL SAVED RESULTS
% =========================================================

Ldata = load(fullfile(protoDir, 'LEACH_results.mat'));
Ddata = load(fullfile(protoDir, 'DEEC_results.mat'));
Pdata = load(fullfile(protoDir, 'PEGASIS_results.mat'));
Rdata = load(fullfile(protoDir, 'RL_HAR_results.mat'));

L = Ldata.LEACH_results;
D = Ddata.DEEC_results;
P = Pdata.PEGASIS_results;
R = Rdata.RL_HAR_results;

% =========================================================
% SETTINGS
% =========================================================

numRounds = L.configuredRounds;
numNodes = 50;
failureRound = 500;

rounds = 1:numRounds;

% =========================================================
% DATA EXTRACTION
% =========================================================

alive_L = L.aliveNodes;
alive_D = D.aliveNodes;
alive_P = P.aliveNodes;
alive_R = R.aliveNodes;

pdr_L = L.sourceReportPDR * 100;
pdr_D = D.sourceReportPDR * 100;
pdr_P = P.sourceReportPDR * 100;
pdr_R = R.sourceReportPDR * 100;

estd_L = L.energyStdDev;
estd_D = D.energyStdDev;
estd_P = P.energyStdDev;
estd_R = R.energyStdDev;

% =========================================================
% SMOOTHING (transparent, for visualization only)
% Window = 15 rounds: moderate smoothing preserves trends
% =========================================================

window = 15;

spdr_L = movmean(pdr_L, window, 'omitnan');
spdr_D = movmean(pdr_D, window, 'omitnan');
spdr_P = movmean(pdr_P, window, 'omitnan');
spdr_R = movmean(pdr_R, window, 'omitnan');

sestd_L = movmean(estd_L, window, 'omitnan');
sestd_D = movmean(estd_D, window, 'omitnan');
sestd_P = movmean(estd_P, window, 'omitnan');
sestd_R = movmean(estd_R, window, 'omitnan');

% =========================================================
% COLORS (high-contrast on white background)
% =========================================================

cLEACH   = [0.000 0.447 0.741];   % blue
cDEEC    = [0.850 0.325 0.098];   % orange
cPEGASIS = [0.466 0.674 0.188];   % green
cRLHAR   = [0.635 0.078 0.584];   % vivid purple

lw = 2.2;
fs = 11;

% =========================================================
% ONE 2x2 FIGURE
% =========================================================

figure( ...
    'Name','Final WSN Protocol Comparison', ...
    'Color','w', ...
    'Position',[100 100 1200 800]);

% ---------------------------------------------------------
% SUBPLOT 1: ALIVE NODES vs ROUND
% ---------------------------------------------------------

subplot(2,2,1);
hold on; grid on; box on;

plot(rounds, alive_L, '-', 'Color', cLEACH,   'LineWidth', lw);
plot(rounds, alive_D, '-', 'Color', cDEEC,    'LineWidth', lw);
plot(rounds, alive_P, '-', 'Color', cPEGASIS, 'LineWidth', lw);
plot(rounds, alive_R, '-', 'Color', cRLHAR,   'LineWidth', lw);

xline(failureRound, 'k--', 'Failure', 'LineWidth', 1.2, ...
    'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'top');

title('Alive Nodes vs Round');
xlabel('Round');
ylabel('Number of Alive Nodes');
xlim([1 numRounds]);
ylim([0 52]);

legend('LEACH','DEEC','PEGASIS','RL-Hybrid', 'Location','southwest');
set(gca, 'FontSize', fs, 'Color', 'w');

% ---------------------------------------------------------
% SUBPLOT 2: PDR vs ROUND (full range)
% ---------------------------------------------------------

subplot(2,2,2);
hold on; grid on; box on;

plot(rounds, spdr_L, '-', 'Color', cLEACH,   'LineWidth', lw);
plot(rounds, spdr_D, '-', 'Color', cDEEC,    'LineWidth', lw);
plot(rounds, spdr_P, '-', 'Color', cPEGASIS, 'LineWidth', lw);
plot(rounds, spdr_R, '-', 'Color', cRLHAR,   'LineWidth', lw);

xline(failureRound, 'k--', 'Failure', 'LineWidth', 1.2, ...
    'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'top');

title('Packet Delivery Ratio vs Round');
xlabel('Round');
ylabel('PDR (%)');
xlim([1 numRounds]);
ylim([0 100]);

legend('LEACH','DEEC','PEGASIS','RL-Hybrid', 'Location','southwest');
set(gca, 'FontSize', fs, 'Color', 'w');

% ---------------------------------------------------------
% SUBPLOT 3: STD DEV OF RESIDUAL ENERGY vs ROUND
% Evaluates energy balancing: lower = more balanced
% ---------------------------------------------------------

subplot(2,2,3);
hold on; grid on; box on;

plot(rounds, sestd_L, '-', 'Color', cLEACH,   'LineWidth', lw);
plot(rounds, sestd_D, '-', 'Color', cDEEC,    'LineWidth', lw);
plot(rounds, sestd_P, '-', 'Color', cPEGASIS, 'LineWidth', lw);
plot(rounds, sestd_R, '-', 'Color', cRLHAR,   'LineWidth', lw);

xline(failureRound, 'k--', 'Failure', 'LineWidth', 1.2, ...
    'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'top');

title('Energy Balance: Std Dev of Residual Energy');
xlabel('Round');
ylabel('Std Dev of Node Energy (J)');
xlim([1 numRounds]);

allStd = [sestd_L(~isnan(sestd_L)), sestd_D(~isnan(sestd_D)), ...
          sestd_P(~isnan(sestd_P)), sestd_R(~isnan(sestd_R))];
if ~isempty(allStd)
    yMax = prctile(allStd, 98) * 1.15;
    if yMax > 0; ylim([0 yMax]); end
end

legend('LEACH','DEEC','PEGASIS','RL-Hybrid', 'Location','northwest');
set(gca, 'FontSize', fs, 'Color', 'w');

% ---------------------------------------------------------
% SUBPLOT 4: PDR AROUND THE FAILURE EVENT (rounds 400-600)
% Evaluates adaptive fault-aware routing
% ---------------------------------------------------------

subplot(2,2,4);
hold on; grid on; box on;

fail_range = 400:600;

plot(fail_range, spdr_L(fail_range), '-', 'Color', cLEACH,   'LineWidth', lw);
plot(fail_range, spdr_D(fail_range), '-', 'Color', cDEEC,    'LineWidth', lw);
plot(fail_range, spdr_P(fail_range), '-', 'Color', cPEGASIS, 'LineWidth', lw);
plot(fail_range, spdr_R(fail_range), '-', 'Color', cRLHAR,   'LineWidth', lw);

xline(failureRound, 'k--', 'Failure', 'LineWidth', 1.2, ...
    'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'top');

title('PDR Around Failure Event (Rounds 400-600)');
xlabel('Round');
ylabel('PDR (%)');
xlim([400 600]);
ylim([0 100]);

legend('LEACH','DEEC','PEGASIS','RL-Hybrid', 'Location','southwest');
set(gca, 'FontSize', fs, 'Color', 'w');

% =========================================================
% PRINT SUMMARY TABLE
% =========================================================

fprintf('\n');
fprintf('==========================================================================\n');
fprintf('FINAL WSN PROTOCOL COMPARISON\n');
fprintf('==========================================================================\n');
fprintf('%-10s %-8s %-8s %-8s %-14s %-16s\n', ...
    'Protocol','FND','HND','LND','Avg PDR (%)','Avg E-StdDev (J)');
fprintf('--------------------------------------------------------------------------\n');

printResult('LEACH',     L, pdr_L, estd_L);
printResult('DEEC',      D, pdr_D, estd_D);
printResult('PEGASIS',   P, pdr_P, estd_P);
printResult('RL-Hybrid', R, pdr_R, estd_R);

fprintf('==========================================================================\n');
fprintf('Experiment: 50 nodes, 600 m, 1000 rounds, failure at round 500\n');
fprintf('Smoothing: %d-round moving average (visualization only)\n', window);
fprintf('==========================================================================\n');

% =========================================================
% HELPER
% =========================================================

function printResult(name, res, pdr, estd)

    if isnan(res.FND); fnd = 'N/A'; else; fnd = num2str(round(res.FND)); end
    if isnan(res.HND); hnd = 'N/A'; else; hnd = num2str(round(res.HND)); end
    if isnan(res.LND); lnd = 'N/A'; else; lnd = num2str(round(res.LND)); end

    avgPDR  = mean(pdr, 'omitnan');
    avgEstd = mean(estd, 'omitnan');

    fprintf('%-10s %-8s %-8s %-8s %-14.2f %-16.4f\n', ...
        name, fnd, hnd, lnd, avgPDR, avgEstd);
end
