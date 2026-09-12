% protocols/PEGASIS.m
function res = PEGASIS(wsn_env, lq_history, success_history, seed)
    rng(seed, 'twister');
    
    numNodes = wsn_env.numNodes;
    E_residual = ones(1, numNodes) * wsn_env.initialEnergy;
    is_alive = true(1, numNodes);
    has_failed = false(1, numNodes);
    
    ar = wsn_env.numRounds;
    m_alive = zeros(1, ar);
    m_totalEnergy = zeros(1, ar);
    m_gen = zeros(1, ar);
    m_del = zeros(1, ar);
    m_delay = zeros(1, ar);
    m_routingEnergy = zeros(1, ar);
    m_energyStdDev = zeros(1, ar);
    
    R_bit = 250e3; T_proc = 0.005; c = 3e8;
    FND = NaN; HND = NaN; LND = NaN;
    
    chain = buildChain(wsn_env, is_alive);
    last_alive = is_alive;
    
    for r = 1:ar
        energy_start = sum(E_residual(is_alive));
        
        % COMMON FAILURE EVENT
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
        
        if any(is_alive ~= last_alive)
            chain = buildChain(wsn_env, is_alive);
            last_alive = is_alive;
        end
        
        % Fetch identical common environment realization
        lq_matrix = lq_history(:,:,r);
        succ_matrix = success_history(:,:,r);
        
        m_gen(r) = num_alive;
        
        leader_idx_in_chain = mod(r, length(chain)) + 1;
        if leader_idx_in_chain == 0; leader_idx_in_chain = 1; end
        leader = chain(leader_idx_in_chain);
        
        node_reports = zeros(1, numNodes);
        node_reports(is_alive) = 1;
        report_delays = zeros(1, numNodes);
        
        for i = 1:(leader_idx_in_chain - 1)
            curr = chain(i);
            next_hop = chain(i+1);
            if is_alive(curr) && is_alive(next_hop)
                [E_residual, node_reports, report_delays] = passToken(...
                    curr, next_hop, E_residual, node_reports, report_delays, ...
                    wsn_env, succ_matrix, R_bit, T_proc, c);
            end
        end
        
        for i = length(chain):-1:(leader_idx_in_chain + 1)
            curr = chain(i);
            next_hop = chain(i-1);
            if is_alive(curr) && is_alive(next_hop)
                [E_residual, node_reports, report_delays] = passToken(...
                    curr, next_hop, E_residual, node_reports, report_delays, ...
                    wsn_env, succ_matrix, R_bit, T_proc, c);
            end
        end
        
        del_this_round = 0; delay_sum_this_round = 0;
        if is_alive(leader)
            reports_carried = node_reports(leader);
            if reports_carried > 0
                E_agg = wsn_env.E_DA * wsn_env.packetSize * reports_carried;
                if E_residual(leader) >= E_agg
                    E_residual(leader) = E_residual(leader) - E_agg;
                    d_bs = sqrt((wsn_env.X(leader)-wsn_env.BS_X)^2 + (wsn_env.Y(leader)-wsn_env.BS_Y)^2);
                    E_tx = tx_energy(wsn_env.packetSize, d_bs, wsn_env);
                    if E_residual(leader) >= E_tx
                        E_residual(leader) = E_residual(leader) - E_tx;
                        if succ_matrix(leader, numNodes+1)
                            del_this_round = del_this_round + reports_carried;
                            hop_delay = (wsn_env.packetSize / R_bit) + T_proc + (d_bs / c);
                            delay_sum_this_round = delay_sum_this_round + report_delays(leader) + reports_carried * hop_delay;
                        end
                    else
                        E_residual(leader) = 0;
                    end
                else
                    E_residual(leader) = 0;
                end
            end
        end
        
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

function chain = buildChain(wsn_env, is_alive)
    alive_idx = find(is_alive);
    if isempty(alive_idx)
        chain = [];
        return;
    end
    max_d = -1; start_node = alive_idx(1);
    for i = 1:length(alive_idx)
        n = alive_idx(i);
        d = sqrt((wsn_env.X(n)-wsn_env.BS_X)^2 + (wsn_env.Y(n)-wsn_env.BS_Y)^2);
        if d > max_d
            max_d = d; start_node = n;
        end
    end
    chain = start_node;
    unvisited = alive_idx(alive_idx ~= start_node);
    curr = start_node;
    while ~isempty(unvisited)
        min_d = inf; next_node = unvisited(1);
        for i = 1:length(unvisited)
            n = unvisited(i);
            d = sqrt((wsn_env.X(curr)-wsn_env.X(n))^2 + (wsn_env.Y(curr)-wsn_env.Y(n))^2);
            if d < min_d
                min_d = d; next_node = n;
            end
        end
        chain = [chain, next_node];
        curr = next_node;
        unvisited = unvisited(unvisited ~= next_node);
    end
end

function [E_residual, node_reports, report_delays] = passToken(curr, next_hop, E_residual, node_reports, report_delays, wsn_env, succ_matrix, R_bit, T_proc, c)
    reports_carried = node_reports(curr);
    if reports_carried == 0; return; end
    d = sqrt((wsn_env.X(curr)-wsn_env.X(next_hop))^2 + (wsn_env.Y(curr)-wsn_env.Y(next_hop))^2);
    E_tx = tx_energy(wsn_env.packetSize, d, wsn_env);
    if E_residual(curr) >= E_tx
        E_residual(curr) = E_residual(curr) - E_tx;
        if succ_matrix(curr, next_hop)
            E_rx = rx_energy(wsn_env.packetSize, wsn_env);
            if E_residual(next_hop) >= E_rx
                E_residual(next_hop) = E_residual(next_hop) - E_rx;
                node_reports(next_hop) = node_reports(next_hop) + reports_carried;
                hop_delay = (wsn_env.packetSize / R_bit) + T_proc + (d / c);
                report_delays(next_hop) = report_delays(next_hop) + report_delays(curr) + reports_carried * hop_delay;
                node_reports(curr) = 0; report_delays(curr) = 0;
            end
        else
            node_reports(curr) = 0; report_delays(curr) = 0;
        end
    else
        E_residual(curr) = 0;
    end
end