% ========================================================================================
%  RL-BASED ADAPTIVE WSN ROUTING (PART 1: ROUTING BENCHMARK & EVALUATION)
% ========================================================================================
%  Master Entry Point for the Part 1 Routing Experiment
%
%  Protocols Evaluated:
%    1. LEACH     - Low-Energy Adaptive Clustering Hierarchy (Heinzelman et al.)
%    2. DEEC      - Distributed Energy-Efficient Clustering (Qing et al.)
%    3. PEGASIS   - Power-Efficient Gathering in Sensor Information Systems (Lindsey et al.)
%    4. RL-Hybrid - Proposed Reinforcement Learning Adaptive Clustering & Multi-Hop Routing
%
%  Scenario Specifications:
%    - Topology: 50 Sensor Nodes uniformly distributed along a 600 m x 50 m river channel
%    - Base Station: Fixed at downstream outlet (X = 600 m, Y = 25 m)
%    - Initial Energy: 2.0 Joules per node (100.0 J total network energy)
%    - Data Packet Size: 4000 bits
%    - Radio Model: Standard First-Order Radio Model (E_elec = 50 nJ/bit, E_fs = 10 pJ/bit/m^2,
%                   E_mp = 0.0013 pJ/bit/m^4, E_DA = 5 nJ/bit, d0 = 87.7 m)
%    - Simulation Duration: 1000 Rounds across 5 Independent Random Seeds (42, 43, 44, 45, 46)
%    - Failure Event: Critical intermediate relay nodes [15, 25, 35] abruptly fail at Round 500
% ========================================================================================

clc; clear; close all;

% Set up paths dynamically relative to repository root
projectRoot = fileparts(mfilename('fullpath'));
if isempty(projectRoot); projectRoot = pwd; end

addpath(fullfile(projectRoot, 'simulation'));
addpath(fullfile(projectRoot, 'protocols'));
addpath(fullfile(projectRoot, 'rl'));
addpath(fullfile(projectRoot, 'analysis'));

fprintf('========================================================================================\n');
fprintf('  RL-BASED ADAPTIVE WSN ROUTING: BENCHMARK & EVALUATION SUITE\n');
fprintf('  Protocols: LEACH | DEEC | PEGASIS | RL-Hybrid (Proposed)\n');
fprintf('========================================================================================\n');
fprintf('  1. Display Validated 5-Seed Dashboard & Summary Table (analysis/final_results.m)\n');
fprintf('  2. Print Statistical Performance Summary across 5 Seeds (print_comprehensive_metrics.m)\n');
fprintf('  3. Validate 5-Seed Trajectory Data Integrity (generate_seed_validation.m)\n');
fprintf('  4. Re-run Full 5-Seed Simulation from Scratch (run_full_evaluation.m)\n');
fprintf('  5. Run Multi-Run Experiment Suite (run_experiments.m)\n');
fprintf('========================================================================================\n');

choice = input('Enter selection [1-5, default=1]: ', 's');
if isempty(strtrim(choice))
    choice = '1';
end

switch strtrim(choice)
    case '1'
        fprintf('\n[Launching analysis/final_results.m...]\n');
        final_results();
    case '2'
        fprintf('\n[Running print_comprehensive_metrics.m...]\n');
        print_comprehensive_metrics();
    case '3'
        fprintf('\n[Running generate_seed_validation.m...]\n');
        generate_seed_validation();
    case '4'
        fprintf('\n[Executing full 5-seed evaluation (~5-10 minutes)...]\n');
        run_full_evaluation();
    case '5'
        fprintf('\n[Executing run_experiments.m...]\n');
        run_experiments();
    otherwise
        fprintf('\n[Defaulting to Option 1: Display Validated Dashboard & Summary Table]\n');
        final_results();
end
