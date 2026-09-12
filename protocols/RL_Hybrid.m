% protocols/RL_Hybrid.m
function res = RL_Hybrid(wsn_env, lq_history, success_history, seed)
    % RL-HAR: Hybrid Adaptive Routing (v2)
    % Combines:
    %   LEACH   - rotating cluster heads
    %   DEEC    - energy-weighted CH election
    %   PEGASIS - localized, short-hop forwarding
    %   RL      - heuristic-initialized Q-learning with 2-tier candidate filtering,
    %             EWMA link quality smoothing, failure learning, and adaptive exploration.
    
    rng(seed, 'twister');
    
    numNodes = wsn_env.numNodes;
    E_residual = ones(1, numNodes) * wsn_env.initialEnergy;
    is_alive = true(1, numNodes);
    has_failed = false(1, numNodes);
    
    ar = wsn_env.numRounds;
    m_alive = zeros(1, ar); m_totalEnergy = zeros(1, ar);
    m_gen = zeros(1, ar); m_del = zeros(1, ar);
    m_delay = zeros(1, ar); m_routingEnergy = zeros(1, ar);
    m_energyStdDev = zeros(1, ar);
    
    R_bit = 250e3; T_proc = 0.005; c = 3e8;
    FND = NaN; HND = NaN; LND = NaN;
    
    % ==============================================================
    % RL PARAMETERS & INITIALIZATION
    % ==============================================================
    alpha = 0.10; gamma = 0.90;
    
    % Adaptive exploration parameters:
    % Start moderate to avoid early exploration energy waste, decay smoothly
    epsilonInitial = 0.25; epsilonMin = 0.02; decay = 0.995;
    epsilon = epsilonInitial;
    
    numStates = 243; % 3^5 discrete states
    numActions = numNodes + 1; % sensor nodes 1..numNodes + Base Station
    
    % Requirement 1: Physically meaningful heuristic Q-initialization
    Q = initializeQTable(numStates, numActions, wsn_env);
    
    % Requirement 7: Local exploration boost for failure recovery
    epsilon_boost = zeros(1, numStates);
    
    % Range constraints:
    % Normal forwarding radius aligned with threshold distance d0 ~ 87.7m
    neighborRange = 100;
    maxHops = 15;
    bs_direct_range = 100;
    
    % Clustering parameters
    p = 0.10; r_left = zeros(1, numNodes);
    
    % ==============================================================
    % Requirement 4: EWMA HISTORICAL LINK QUALITY INITIALIZATION
    % Legitimate deployment geometry estimate, updated online via outcomes
    % ==============================================================
    LQ_est = zeros(numNodes, numActions);
    for i = 1:numNodes
        for j = 1:numNodes
            if i ~= j
                d_ij = sqrt((wsn_env.X(i)-wsn_env.X(j))^2 + (wsn_env.Y(i)-wsn_env.Y(j))^2);
                LQ_est(i, j) = max(0.1, min(0.95, 1.0 - (d_ij / (wsn_env.riverLength * 0.8))));
            end
        end
        d_ib = sqrt((wsn_env.X(i)-wsn_env.BS_X)^2 + (wsn_env.Y(i)-wsn_env.BS_Y)^2);
        LQ_est(i, numNodes + 1) = max(0.1, min(0.95, 1.0 - (d_ib / (wsn_env.riverLength * 1.2))));
    end
    beta_ewma = 0.20; % EWMA smoothing factor
    
    % ==============================================================
    % DIAGNOSTICS TRACKERS (Requirement 13)
    % ==============================================================
    diag_total_routing_decisions = 0;
    diag_successful_routes = 0;
    diag_failed_routes = 0;
    diag_deadend_events = 0;
    diag_bs_deliveries = 0;
    diag_q_updates = 0;
    diag_total_hops_success = 0;
    diag_total_hops_fail = 0;
    diag_explore_actions = 0;
    diag_exploit_actions = 0;
    diag_retries_attempted = 0;
    diag_retries_succeeded = 0;
    
    min_rx_energy = rx_energy(wsn_env.packetSize, wsn_env);
    
    for r = 1:ar
        energy_start = sum(E_residual(is_alive));
        node_load = zeros(1, numNodes);
        
        % COMMON FAILURE EVENT AT ROUND 500
        if r == 500
            failedNodes = [15, 25, 35];
            for fn = failedNodes
                if fn <= numNodes
                    has_failed(fn) = true;
                end
            end
        end
        is_alive = (E_residual > 0) & ~has_failed;
        num_alive = sum(is_alive);
        
        if num_alive == 0
            if isnan(LND); LND = r-1; end
            m_alive(r:end) = NaN; m_totalEnergy(r:end) = NaN;
            m_gen(r:end) = NaN; m_del(r:end) = NaN;
            m_delay(r:end) = NaN; m_routingEnergy(r:end) = NaN;
            m_energyStdDev(r:end) = NaN;
            break;
        end
        
        if isnan(FND) && num_alive < numNodes; FND = r; end
        if isnan(HND) && num_alive <= numNodes/2; HND = r; end
        
        lq_matrix = lq_history(:,:,r);
        succ_matrix = success_history(:,:,r);
        
        m_gen(r) = num_alive;
        
        % ==============================================================
        % PHASE 1: CH Selection - DEEC-style energy-weighted
        % ==============================================================
        is_CH = false(1, numNodes);
        E_avg = max(1e-6, sum(E_residual(is_alive)) / num_alive);
        for i = 1:numNodes
            if is_alive(i)
                if r_left(i) <= 0
                    p_i = p * (E_residual(i) / E_avg);
                    p_i = min(p_i, 1.0);
                    thresh_denom = 1 - p_i * mod(r, round(1/p));
                    if thresh_denom <= 0; thresh_denom = 1; end
                    if rand() <= (p_i / thresh_denom)
                        is_CH(i) = true;
                        r_left(i) = round(1/p) - 1;
                    end
                else
                    r_left(i) = r_left(i) - 1;
                end
            end
        end
        
        min_CHs = min(3, num_alive);
        while sum(is_CH) < min_CHs
            alive_idx = find(is_alive & ~is_CH);
            if isempty(alive_idx); break; end
            if sum(is_CH) == 0
                [~, max_e_pos] = max(E_residual(alive_idx));
                is_CH(alive_idx(max_e_pos)) = true;
            else
                curr_chs = find(is_CH);
                best_d_sep = -inf; best_cand = alive_idx(1);
                for a_cand = alive_idx
                    min_d_to_existing = min(sqrt((wsn_env.X(a_cand)-wsn_env.X(curr_chs)).^2 + ...
                                                 (wsn_env.Y(a_cand)-wsn_env.Y(curr_chs)).^2));
                    if min_d_to_existing > best_d_sep
                        best_d_sep = min_d_to_existing;
                        best_cand = a_cand;
                    end
                end
                is_CH(best_cand) = true;
            end
        end
        
        ch_idx = find(is_CH);
        node_reports = zeros(1, numNodes);
        node_reports(is_alive) = 1;
        report_delays = zeros(1, numNodes);
        
        % ==============================================================
        % PHASE 2: Energy-aware Member-to-CH Association
        % ==============================================================
        for i = 1:numNodes
            if is_alive(i) && ~is_CH(i)
                best_cost = inf; best_ch = ch_idx(1); best_d = inf;
                for j = 1:length(ch_idx)
                    ch = ch_idx(j);
                    d = sqrt((wsn_env.X(i)-wsn_env.X(ch))^2 + (wsn_env.Y(i)-wsn_env.Y(ch))^2);
                    cost = d * (1.0 + 0.25 * (1.0 - E_residual(ch) / max(1e-6, wsn_env.initialEnergy)));
                    if cost < best_cost
                        best_cost = cost; best_ch = ch; best_d = d;
                    end
                end
                
                % If nearest CH is too far (> neighborRange), member avoids massive d^4 transmission
                % and instead routes autonomously via Q-learning multi-hop
                if best_d > neighborRange
                    is_CH(i) = true;
                    continue;
                end
                
                d = best_d;
                E_tx = tx_energy(wsn_env.packetSize, d, wsn_env);
                if E_residual(i) >= E_tx
                    E_residual(i) = E_residual(i) - E_tx;
                    success = succ_matrix(i, best_ch);
                    % Update EWMA link quality for member-to-CH link
                    LQ_est(i, best_ch) = (1 - beta_ewma) * LQ_est(i, best_ch) + beta_ewma * double(success);
                    
                    if success
                        E_rx = rx_energy(wsn_env.packetSize, wsn_env);
                        if E_residual(best_ch) >= E_rx
                            E_residual(best_ch) = E_residual(best_ch) - E_rx;
                            node_reports(best_ch) = node_reports(best_ch) + 1;
                            hop_delay = (wsn_env.packetSize / R_bit) + T_proc + (d / c);
                            report_delays(best_ch) = report_delays(best_ch) + hop_delay;
                        end
                    end
                else
                    E_residual(i) = 0;
                end
            end
        end
        
        % ==============================================================
        % PHASE 3: Inter-Cluster Multi-hop Routing via Q-learning
        % ==============================================================
        del_this_round = 0; delay_sum_this_round = 0;
        for i = 1:numNodes
            if is_alive(i) && is_CH(i)
                reports_carried = node_reports(i);
                if reports_carried > 0
                    E_agg = wsn_env.E_DA * wsn_env.packetSize * reports_carried;
                    if E_residual(i) >= E_agg
                        E_residual(i) = E_residual(i) - E_agg;
                        
                        curr = i; hops = 0;
                        visited = false(1, numNodes);
                        visited(curr) = true;
                        route_succeeded = false;
                        
                        curr_delay = report_delays(i);
                        
                        % State evaluation with EWMA link quality (Requirement 3 & 4)
                        curr_s_idx = getState(curr, E_residual, wsn_env.initialEnergy, ...
                                              node_load, LQ_est, wsn_env, neighborRange);
                        
                        diag_total_routing_decisions = diag_total_routing_decisions + 1;
                        
                        while hops < maxHops
                            % --------------------------------------------------
                            % Requirement 2: Two-Tier Candidate Action Filtering
                            % --------------------------------------------------
                            normal_cands = [];
                            emergency_cands = [];
                            
                            d_curr_bs = sqrt((wsn_env.X(curr)-wsn_env.BS_X)^2 + (wsn_env.Y(curr)-wsn_env.BS_Y)^2);
                            
                            for j = 1:numNodes
                                if is_alive(j) && ~visited(j) && ~has_failed(j)
                                    d_j = sqrt((wsn_env.X(curr)-wsn_env.X(j))^2 + (wsn_env.Y(curr)-wsn_env.Y(j))^2);
                                    d_j_bs = sqrt((wsn_env.X(j)-wsn_env.BS_X)^2 + (wsn_env.Y(j)-wsn_env.BS_Y)^2);
                                    prog_j = d_curr_bs - d_j_bs;
                                    
                                    % Tier 1: Normal candidate
                                    if d_j <= neighborRange && prog_j > 0 && ...
                                       E_residual(j) > (0.05 * wsn_env.initialEnergy) && ...
                                       LQ_est(curr, j) >= 0.25
                                        normal_cands(end+1) = j;
                                    end
                                    
                                    % Tier 2: Emergency candidate (for failure recovery)
                                    if d_j <= 200 && prog_j > -10 && E_residual(j) >= min_rx_energy
                                        emergency_cands(end+1) = j;
                                    end
                                end
                            end
                            
                            % Base Station candidate checks
                            if d_curr_bs <= bs_direct_range
                                normal_cands(end+1) = numNodes + 1;
                            end
                            % Requirement 2: In emergency set, Base Station is always allowed
                            % as the destination of last resort to recover from failures/gaps.
                            emergency_cands(end+1) = numNodes + 1;
                            
                            if ~isempty(normal_cands)
                                candidates = normal_cands;
                            else
                                candidates = emergency_cands;
                            end
                            
                            if isempty(candidates)
                                diag_deadend_events = diag_deadend_events + 1;
                                break;
                            end
                            
                            % --------------------------------------------------
                            % Action Selection with Adaptive Exploration
                            % --------------------------------------------------
                            hop_done = false;
                            tried = false(1, numActions);
                            cands_remaining = candidates(~tried(candidates));
                            
                            while ~hop_done && ~isempty(cands_remaining)
                                eff_epsilon = min(0.35, epsilon + epsilon_boost(curr_s_idx));
                                
                                if rand() < eff_epsilon
                                    diag_explore_actions = diag_explore_actions + 1;
                                else
                                    diag_exploit_actions = diag_exploit_actions + 1;
                                end
                                
                                action = chooseAction(curr_s_idx, cands_remaining, Q, eff_epsilon);
                                
                                if action == -1
                                    break;
                                end
                                tried(action) = true;
                                next_hop = action;
                                hops = hops + 1;
                                
                                if next_hop == numNodes + 1
                                    % ==========================================
                                    % Direct Hop to Base Station
                                    % ==========================================
                                    d_bs = d_curr_bs;
                                    E_tx = tx_energy(wsn_env.packetSize, d_bs, wsn_env);
                                    
                                    if E_residual(curr) >= E_tx
                                        E_residual(curr) = E_residual(curr) - E_tx;
                                        success = succ_matrix(curr, numNodes + 1);
                                        
                                        % Requirement 4: EWMA link quality update
                                        LQ_est(curr, numNodes + 1) = (1 - beta_ewma) * LQ_est(curr, numNodes + 1) ...
                                                                   + beta_ewma * double(success);
                                        lq_val = LQ_est(curr, numNodes + 1);
                                        
                                        % Requirement 5: Reward calculation
                                        reward = calculateReward(curr, next_hop, success, true, ...
                                            E_residual, wsn_env.initialEnergy, lq_val, ...
                                            d_bs, wsn_env.riverLength, hops, maxHops, ...
                                            node_load, numNodes);
                                        
                                        Q = updateQTable(Q, curr_s_idx, action, reward, 0, alpha, gamma);
                                        diag_q_updates = diag_q_updates + 1;
                                        
                                        if success
                                            del_this_round = del_this_round + reports_carried;
                                            hop_delay = (wsn_env.packetSize / R_bit) + T_proc + (d_bs / c);
                                            curr_delay = curr_delay + reports_carried * hop_delay;
                                            delay_sum_this_round = delay_sum_this_round + curr_delay;
                                            route_succeeded = true;
                                            diag_bs_deliveries = diag_bs_deliveries + 1;
                                            % Cool down exploration boost on success
                                            epsilon_boost(curr_s_idx) = max(0, epsilon_boost(curr_s_idx) * 0.85);
                                        else
                                            % Requirement 6 & 7: Learn failure and boost exploration
                                            epsilon_boost(curr_s_idx) = min(0.25, epsilon_boost(curr_s_idx) + 0.10);
                                        end
                                        hop_done = true;
                                    else
                                        E_residual(curr) = 0;
                                        reward = calculateReward(curr, next_hop, false, true, ...
                                            E_residual, wsn_env.initialEnergy, 0, ...
                                            d_bs, wsn_env.riverLength, hops, maxHops, ...
                                            node_load, numNodes);
                                        Q = updateQTable(Q, curr_s_idx, action, reward, 0, alpha, gamma);
                                        diag_q_updates = diag_q_updates + 1;
                                        hop_done = true;
                                    end
                                else
                                    % ==========================================
                                    % Intermediate Forwarding Hop to Relay Node
                                    % ==========================================
                                    d = sqrt((wsn_env.X(curr)-wsn_env.X(next_hop))^2 + (wsn_env.Y(curr)-wsn_env.Y(next_hop))^2);
                                    E_tx = tx_energy(wsn_env.packetSize, d, wsn_env);
                                    
                                    if E_residual(curr) >= E_tx
                                        E_residual(curr) = E_residual(curr) - E_tx;
                                        
                                        % Check if next hop has failed (e.g. at round 500)
                                        if has_failed(next_hop)
                                            success = false;
                                        else
                                            success = succ_matrix(curr, next_hop);
                                        end
                                        
                                        % Requirement 4: EWMA link quality update
                                        LQ_est(curr, next_hop) = (1 - beta_ewma) * LQ_est(curr, next_hop) ...
                                                               + beta_ewma * double(success);
                                        lq_val = LQ_est(curr, next_hop);
                                        
                                        if success
                                            E_rx = rx_energy(wsn_env.packetSize, wsn_env);
                                            if E_residual(next_hop) >= E_rx
                                                E_residual(next_hop) = E_residual(next_hop) - E_rx;
                                                node_load(next_hop) = node_load(next_hop) + 1;
                                                
                                                d_curr_bs_now = sqrt((wsn_env.X(curr)-wsn_env.BS_X)^2 + (wsn_env.Y(curr)-wsn_env.BS_Y)^2);
                                                d_next_bs = sqrt((wsn_env.X(next_hop)-wsn_env.BS_X)^2 + (wsn_env.Y(next_hop)-wsn_env.BS_Y)^2);
                                                dist_prog = d_curr_bs_now - d_next_bs;
                                                
                                                % Requirement 5: Reward
                                                reward = calculateReward(curr, next_hop, true, false, ...
                                                    E_residual, wsn_env.initialEnergy, lq_val, ...
                                                    dist_prog, wsn_env.riverLength, hops, maxHops, ...
                                                    node_load, numNodes);
                                                
                                                % Lookahead for Q-learning Bellman update
                                                next_s_idx = getState(next_hop, E_residual, wsn_env.initialEnergy, ...
                                                                      node_load, LQ_est, wsn_env, neighborRange);
                                                
                                                % Find next candidates from next_hop
                                                next_cands = [];
                                                d_next_bs_val = d_next_bs;
                                                for j = 1:numNodes
                                                    if is_alive(j) && ~visited(j) && j ~= next_hop && ~has_failed(j)
                                                        dn = sqrt((wsn_env.X(next_hop)-wsn_env.X(j))^2 + (wsn_env.Y(next_hop)-wsn_env.Y(j))^2);
                                                        dn_bs = sqrt((wsn_env.X(j)-wsn_env.BS_X)^2 + (wsn_env.Y(j)-wsn_env.BS_Y)^2);
                                                        if dn <= neighborRange && (d_next_bs_val - dn_bs) > 0
                                                            next_cands(end+1) = j;
                                                        end
                                                    end
                                                end
                                                if d_next_bs_val <= bs_direct_range
                                                    next_cands(end+1) = numNodes + 1;
                                                end
                                                
                                                if isempty(next_cands)
                                                    next_max_q = 0;
                                                else
                                                    next_max_q = max(Q(next_s_idx, next_cands));
                                                end
                                                
                                                Q = updateQTable(Q, curr_s_idx, action, reward, next_max_q, alpha, gamma);
                                                diag_q_updates = diag_q_updates + 1;
                                                
                                                hop_delay = (wsn_env.packetSize / R_bit) + T_proc + (d / c);
                                                curr_delay = curr_delay + reports_carried * hop_delay;
                                                
                                                % Decay exploration boost on confirmed good hop
                                                epsilon_boost(curr_s_idx) = max(0, epsilon_boost(curr_s_idx) * 0.85);
                                                
                                                % Advance state & current node
                                                curr = next_hop;
                                                curr_s_idx = next_s_idx;
                                                visited(curr) = true;
                                                hop_done = true;
                                            else
                                                % Next hop has insufficient RX energy
                                                E_residual(next_hop) = 0;
                                                reward = calculateReward(curr, next_hop, false, false, ...
                                                    E_residual, wsn_env.initialEnergy, lq_val, ...
                                                    0, wsn_env.riverLength, hops, maxHops, ...
                                                    node_load, numNodes);
                                                Q = updateQTable(Q, curr_s_idx, action, reward, 0, alpha, gamma);
                                                diag_q_updates = diag_q_updates + 1;
                                                epsilon_boost(curr_s_idx) = min(0.25, epsilon_boost(curr_s_idx) + 0.10);
                                                hops = hops - 1;
                                                diag_retries_attempted = diag_retries_attempted + 1;
                                            end
                                        else
                                            % Requirement 6: Link or node failure detected
                                            reward = calculateReward(curr, next_hop, false, false, ...
                                                E_residual, wsn_env.initialEnergy, lq_val, ...
                                                0, wsn_env.riverLength, hops, maxHops, ...
                                                node_load, numNodes);
                                            Q = updateQTable(Q, curr_s_idx, action, reward, 0, alpha, gamma);
                                            diag_q_updates = diag_q_updates + 1;
                                            epsilon_boost(curr_s_idx) = min(0.25, epsilon_boost(curr_s_idx) + 0.10);
                                            hops = hops - 1;
                                            diag_retries_attempted = diag_retries_attempted + 1;
                                        end
                                    else
                                        % Current node has insufficient TX energy
                                        E_residual(curr) = 0;
                                        reward = calculateReward(curr, next_hop, false, false, ...
                                            E_residual, wsn_env.initialEnergy, 0, ...
                                            0, wsn_env.riverLength, hops, maxHops, ...
                                            node_load, numNodes);
                                        Q = updateQTable(Q, curr_s_idx, action, reward, 0, alpha, gamma);
                                        diag_q_updates = diag_q_updates + 1;
                                        hop_done = true;
                                    end
                                end
                                
                                cands_remaining = candidates(~tried(candidates));
                            end % candidate retry loop
                            
                            if ~hop_done
                                diag_deadend_events = diag_deadend_events + 1;
                                break;
                            end
                            
                            if route_succeeded || E_residual(curr) <= 0
                                break;
                            end
                        end % hop loop
                        
                        if route_succeeded
                            diag_successful_routes = diag_successful_routes + 1;
                            diag_total_hops_success = diag_total_hops_success + hops;
                        else
                            diag_failed_routes = diag_failed_routes + 1;
                            diag_total_hops_fail = diag_total_hops_fail + hops;
                        end
                    else
                        E_residual(i) = 0;
                    end
                end
            end
        end
        
        % Decay base epsilon smoothly
        epsilon = max(epsilonMin, epsilon * decay);
        % Also gradually decay any lingering exploration boosts
        epsilon_boost = max(0, epsilon_boost * 0.98);
        
        E_residual(E_residual < 0) = 0;
        is_alive = (E_residual > 0) & ~has_failed;
        
        energy_end = sum(E_residual(is_alive));
        m_alive(r) = sum(is_alive);
        m_totalEnergy(r) = sum(E_residual);
        m_del(r) = del_this_round;
        if del_this_round > 0
            m_delay(r) = delay_sum_this_round / del_this_round;
        else
            m_delay(r) = NaN;
        end
        m_routingEnergy(r) = energy_start - energy_end;
        
        alive_energies = E_residual(is_alive);
        if length(alive_energies) > 1
            m_energyStdDev(r) = std(alive_energies);
        else
            m_energyStdDev(r) = 0;
        end
    end
    
    % Requirement 13: Summary Diagnostics Report
    fprintf('  [RL-HAR v2 Diagnostics] Seed: %d\n', seed);
    fprintf('    Routing Decisions      : %d\n', diag_total_routing_decisions);
    fprintf('    Successful Routes      : %d\n', diag_successful_routes);
    fprintf('    Failed Routes          : %d\n', diag_failed_routes);
    fprintf('    Dead-end Events        : %d\n', diag_deadend_events);
    fprintf('    Direct BS Deliveries   : %d\n', diag_bs_deliveries);
    fprintf('    Q-table Updates        : %d\n', diag_q_updates);
    fprintf('    Exploration Actions    : %d\n', diag_explore_actions);
    fprintf('    Exploitation Actions   : %d\n', diag_exploit_actions);
    if diag_successful_routes > 0
        fprintf('    Avg Hops (Successful)  : %.2f\n', diag_total_hops_success / diag_successful_routes);
    end
    total_del = sum(m_del, 'omitnan');
    total_gen = sum(m_gen, 'omitnan');
    fprintf('    Delivered Reports      : %.0f / %.0f (PDR: %.2f%%)\n', ...
        total_del, total_gen, 100 * total_del / max(1, total_gen));
    fprintf('    FND: %s | HND: %s | LND: %s\n', mat2str(FND), mat2str(HND), mat2str(LND));
    fprintf('    Total Energy Consumed  : %.4f J\n', sum(m_routingEnergy, 'omitnan'));
    fprintf('    Final Epsilon          : %.4f\n', epsilon);
    
    res = struct();
    res.configuredRounds = wsn_env.numRounds;
    res.actualRoundsSimulated = find(~isnan(m_alive), 1, 'last');
    if isempty(res.actualRoundsSimulated); res.actualRoundsSimulated = ar; end
    res.wsn_env = wsn_env;
    res.aliveNodes = m_alive;
    res.totalResidualEnergy = m_totalEnergy;
    res.generatedSourceReports = m_gen;
    res.deliveredSourceReports = m_del;
    m_pdr = m_del ./ max(1, m_gen);
    m_pdr(isnan(m_alive)) = NaN;
    res.sourceReportPDR = m_pdr;
    res.averageEndToEndDelay = m_delay;
    res.routingEnergyConsumedThisRound = m_routingEnergy;
    res.energyStdDev = m_energyStdDev;
    res.FND = FND; res.HND = HND; res.LND = LND;
end
