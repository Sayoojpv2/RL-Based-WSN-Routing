% rl/calculateReward.m
function reward = calculateReward(curr, next_hop, success, is_BS, ...
        E_residual, E_initial, lq_value, dist_progress, max_dist, ...
        hops, max_hops, node_load, numNodes)
    % calculateReward - Normalized, multi-objective RL reward function.
    %
    % Objectives encouraged:
    %   1. Terminal packet delivery to Base Station (+1.5 to +2.0)
    %   2. Forward geographic progress toward Base Station (+0.30 * prog_term)
    %   3. Healthy relay residual energy (+0.25 * e_relay)
    %   4. High link quality (+0.20 * lq_term)
    %
    % Behaviors penalized:
    %   1. Failed transmissions / dead relays (-1.0)
    %   2. Overloaded relay bottleneck congestion (-0.10 * load_penalty)
    %   3. Excessive hop count / route meandering (-0.15 * hop_penalty)
    %
    % All terms are strictly normalized to [-1, 1] or [0, 1] for numerical stability.

    % --- 1. Transmission / Route Failure Penalty ---
    % Rationale: Failed transmissions waste energy and fail delivery.
    % Provides an immediate negative gradient (-1.0) to update Q-values away from failed links.
    if ~success
        reward = -1.0;
        return;
    end

    % --- 2. Terminal Delivery to Base Station ---
    % Rationale: End-to-end packet delivery is the primary network mission.
    % Base reward of +1.5 with up to +0.5 bonus for route compactness (fewer hops).
    if is_BS
        hop_efficiency = max(0, 1.0 - (hops / max(1, max_hops)));
        reward = 1.5 + 0.5 * hop_efficiency;
        return;
    end

    % --- 3. Intermediate Relay Hop (Successful) ---

    % A. Forward Progress toward Base Station (Normalized to d0 ~ 87.7m)
    % Rationale: Encourages packet movement toward the sink; penalizes backward movement.
    d0_ref = 87.7;
    prog_term = max(-1.0, min(1.0, dist_progress / d0_ref));

    % B. Relay Residual Energy Health (0..1)
    % Rationale: Preserves low-energy nodes by preferring relays with abundant remaining energy.
    if next_hop >= 1 && next_hop <= numNodes
        e_relay = max(0, min(1.0, E_residual(next_hop) / max(1e-6, E_initial)));
    else
        e_relay = 1.0;
    end

    % C. Link Quality Term (0..1)
    % Rationale: Prefers reliable links over marginal/fading links, directly improving PDR.
    lq_term = max(0, min(1.0, lq_value));

    % D. Relay Load Balancing Penalty (0..1)
    % Rationale: Prevents hot-spots and relay exhaustion by penalizing nodes carrying > average load.
    avg_load = max(1, sum(node_load) / max(1, numNodes));
    if next_hop >= 1 && next_hop <= numNodes
        load_ratio = node_load(next_hop) / avg_load;
        load_penalty = max(0, min(1.0, load_ratio - 1.0));
    else
        load_penalty = 0;
    end

    % E. Hop Count Penalty (0..1)
    % Rationale: Discourages excessive multi-hop routing and latency accumulation.
    hop_penalty = (hops / max(1, max_hops)) * 0.15;

    % Weighted Multi-Objective Combination
    % Weights sum to 0.75 positive potential - penalties, keeping intermediate hops < 0.75
    % and terminal delivery (+1.5 to +2.0) clearly dominant.
    reward = 0.30 * prog_term ...
           + 0.25 * e_relay ...
           + 0.20 * lq_term ...
           - 0.10 * load_penalty ...
           - hop_penalty;
end
