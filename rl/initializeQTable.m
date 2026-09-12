% rl/initializeQTable.m
function Q = initializeQTable(numStates, numActions, wsn_env)
    % initializeQTable - Creates a physically-meaningful heuristic initial Q-table.
    %
    % Inputs:
    %   numStates  - Number of discrete states (243 = 3^5)
    %   numActions - Number of actions (numNodes + 1, where +1 is Base Station)
    %   wsn_env    - (Optional) WSN environment struct with topology and radio parameters
    %
    % If wsn_env is not provided, defaults to zeros for backward compatibility.
    % When provided, initializes Q-values based on normalized combinations of:
    %   - Relay communication distance / transmission energy efficiency
    %   - Geographic progress toward Base Station
    %   - Expected link quality from propagation geometry
    %   - Candidate residual energy health

    if nargin < 3 || isempty(wsn_env)
        Q = zeros(numStates, numActions);
        return;
    end

    numNodes = wsn_env.numNodes;
    BS_X = wsn_env.BS_X;
    BS_Y = wsn_env.BS_Y;
    riverLength = wsn_env.riverLength;
    d0 = wsn_env.d0;

    Q = zeros(numStates, numActions);

    % Representative X-coordinate positions for the 3 distance-to-BS bins (s5):
    % s5 = 1: Far from BS (upstream, ~100m)
    % s5 = 2: Mid distance (~300m)
    % s5 = 3: Close to BS (~500m)
    zone_X = [riverLength * 0.17, riverLength * 0.50, riverLength * 0.83];
    zone_Y = wsn_env.riverWidth / 2;

    cand_energy_levels = [0.25, 0.55, 0.90];

    % Reference transmission energy at threshold distance d0
    E_ref = tx_energy(wsn_env.packetSize, d0, wsn_env);

    for s = 1:numStates
        % Decode state indices (s1, s2, s3, s4, s5) from 1-based index
        rem_s = s - 1;
        s1 = floor(rem_s / 81) + 1; rem_s = mod(rem_s, 81);
        s2 = floor(rem_s / 27) + 1; rem_s = mod(rem_s, 27);
        s3 = floor(rem_s / 9)  + 1; rem_s = mod(rem_s, 9);
        s4 = floor(rem_s / 3)  + 1;
        s5 = mod(rem_s, 3)     + 1;

        curr_X = zone_X(s5);
        curr_Y = zone_Y;
        d_curr_bs = sqrt((curr_X - BS_X)^2 + (curr_Y - BS_Y)^2);
        e_cand = cand_energy_levels(s2);

        for a = 1:numActions
            if a <= numNodes
                % Action is an intermediate sensor node
                cand_X = wsn_env.X(a);
                cand_Y = wsn_env.Y(a);
                d_hop = sqrt((curr_X - cand_X)^2 + (curr_Y - cand_Y)^2);
                d_cand_bs = sqrt((cand_X - BS_X)^2 + (cand_Y - BS_Y)^2);
                delta_prog = d_curr_bs - d_cand_bs;

                if delta_prog <= 0
                    % Backward hop: penalize to discourage retrograde movement
                    Q(s, a) = 0.01;
                elseif d_hop > 150
                    % Overly long hop: penalize excessive multipath energy
                    Q(s, a) = 0.05;
                else
                    % Normal forward candidate
                    E_tx = tx_energy(wsn_env.packetSize, d_hop, wsn_env);
                    f_energy = max(0, 1.0 - (E_tx / (2.0 * E_ref)));
                    f_prog = min(1.0, max(0, delta_prog / d0));
                    lq_est = max(0.1, min(0.95, 1.0 - (d_hop / (riverLength * 0.8))));

                    q_val = 0.35 * f_energy + 0.30 * f_prog + 0.20 * lq_est + 0.15 * e_cand;
                    Q(s, a) = max(0.05, min(0.95, q_val));
                end
            else
                % Action is Base Station (a = numNodes + 1)
                d_bs = d_curr_bs;
                if s5 == 3 && d_bs <= 120
                    % Close to BS: direct transmission is viable and desirable
                    E_tx = tx_energy(wsn_env.packetSize, d_bs, wsn_env);
                    f_energy = max(0, 1.0 - (E_tx / (2.0 * E_ref)));
                    lq_est = max(0.1, min(0.95, 1.0 - (d_bs / (riverLength * 1.2))));
                    Q(s, a) = 0.50 * f_energy + 0.30 * 1.0 + 0.20 * lq_est;
                else
                    % Far/Mid from BS: direct hop wastes massive d^4 energy
                    Q(s, a) = 0.02;
                end
            end
        end
    end
end
