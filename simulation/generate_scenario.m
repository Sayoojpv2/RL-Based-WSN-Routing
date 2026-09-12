% simulation/generate_scenario.m
function [wsn_env, lq_history, success_history] = generate_scenario(seed)
    rng(seed, 'twister');
    
    wsn_env.numNodes = 50;
    wsn_env.riverLength = 600; % Reduced to 600m to allow feasible baseline survival
    wsn_env.riverWidth = 50;
    
    % Place BS at the downstream end
    wsn_env.BS_X = wsn_env.riverLength;
    wsn_env.BS_Y = wsn_env.riverWidth / 2;
    
    % Place nodes randomly along the river
    wsn_env.X = rand(1, wsn_env.numNodes) * wsn_env.riverLength;
    wsn_env.Y = rand(1, wsn_env.numNodes) * wsn_env.riverWidth;
    
    % Sort nodes by X-coordinate
    [wsn_env.X, sort_idx] = sort(wsn_env.X);
    wsn_env.Y = wsn_env.Y(sort_idx);
    
    wsn_env.initialEnergy = 2.0; % 2.0 Joules
    wsn_env.packetSize = 4000; % bits
    wsn_env.numRounds = 1000;  % 1000 rounds
    
    % Standard First-Order Radio Model Parameters
    wsn_env.E_elec = 50e-9;
    wsn_env.E_fs = 10e-12;
    wsn_env.E_mp = 0.0013e-12;
    wsn_env.E_DA = 5e-9;
    wsn_env.d0 = sqrt(wsn_env.E_fs / wsn_env.E_mp);
    
    wsn_env.topologySeed = seed;
    
    % Pre-allocate Common Link Conditions (numNodes x numNodes+1 x numRounds)
    numNodes = wsn_env.numNodes;
    numRounds = wsn_env.numRounds;
    lq_history = zeros(numNodes, numNodes+1, numRounds);
    success_history = false(numNodes, numNodes+1, numRounds);
    
    % Pre-generate deterministic fading and packet success for ALL rounds
    for r = 1:numRounds
        rng(seed + r, 'twister');
        for i = 1:numNodes
            % Node-to-Node links
            for j = 1:numNodes
                if i ~= j
                    d = sqrt((wsn_env.X(i) - wsn_env.X(j))^2 + (wsn_env.Y(i) - wsn_env.Y(j))^2);
                    base_lq = 1.0 - (d / (wsn_env.riverLength * 0.8)); 
                    noise = 0.3 * (rand() - 0.5);
                    lq_history(i,j,r) = max(0.1, min(0.95, base_lq + noise));
                end
            end
            % Node-to-BS link (Node index numNodes+1)
            d_bs = sqrt((wsn_env.X(i) - wsn_env.BS_X)^2 + (wsn_env.Y(i) - wsn_env.BS_Y)^2);
            base_lq_bs = 1.0 - (d_bs / (wsn_env.riverLength * 1.2));
            noise_bs = 0.3 * (rand() - 0.5);
            lq_history(i, numNodes+1, r) = max(0.1, min(0.95, base_lq_bs + noise_bs));
        end
        % Success is governed by standard probability comparison
        success_history(:,:,r) = rand(numNodes, numNodes+1) < lq_history(:,:,r);
    end
end
