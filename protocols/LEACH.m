% protocols/LEACH.m
function res = LEACH(wsn_env, lq_history, success_history, seed)
    rng(seed, 'twister'); % Use reproducible seed for protocol-specific probabilistic decisions
    
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
    
    p = 0.1; 
    r_left = zeros(1, numNodes); 
    
    R_bit = 250e3; T_proc = 0.005; c = 3e8;
    FND = NaN; HND = NaN; LND = NaN;
    
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
        
        % Fetch identical common environment realization
        lq_matrix = lq_history(:,:,r);
        succ_matrix = success_history(:,:,r);
        
        m_gen(r) = num_alive;
        
        % CH Selection
        is_CH = false(1, numNodes);
        for i = 1:numNodes
            if is_alive(i)
                if r_left(i) <= 0
                    if rand() <= (p / (1 - p * mod(r, 1/p)))
                        is_CH(i) = true;
                        r_left(i) = round(1/p) - 1;
                    end
                else
                    r_left(i) = r_left(i) - 1;
                end
            end
        end
        
        if sum(is_CH) == 0
            alive_idx = find(is_alive);
            is_CH(alive_idx(randi(length(alive_idx)))) = true;
        end
        
        ch_idx = find(is_CH);
        node_reports = zeros(1, numNodes);
        node_reports(is_alive) = 1;
        report_delays = zeros(1, numNodes);
        
        % Member Phase
        for i = 1:numNodes
            if is_alive(i) && ~is_CH(i)
                min_d = inf; best_ch = ch_idx(1);
                for j = 1:length(ch_idx)
                    ch = ch_idx(j);
                    d = sqrt((wsn_env.X(i)-wsn_env.X(ch))^2 + (wsn_env.Y(i)-wsn_env.Y(ch))^2);
                    if d < min_d
                        min_d = d; best_ch = ch;
                    end
                end
                
                d = min_d;
                E_tx = tx_energy(wsn_env.packetSize, d, wsn_env);
                if E_residual(i) >= E_tx
                    E_residual(i) = E_residual(i) - E_tx;
                    if succ_matrix(i, best_ch)
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
        
        % CH Phase
        del_this_round = 0; delay_sum_this_round = 0;
        for i = 1:numNodes
            if is_alive(i) && is_CH(i)
                reports_carried = node_reports(i);
                if reports_carried > 0
                    E_agg = wsn_env.E_DA * wsn_env.packetSize * reports_carried;
                    if E_residual(i) >= E_agg
                        E_residual(i) = E_residual(i) - E_agg;
                        
                        d_bs = sqrt((wsn_env.X(i)-wsn_env.BS_X)^2 + (wsn_env.Y(i)-wsn_env.BS_Y)^2);
                        E_tx = tx_energy(wsn_env.packetSize, d_bs, wsn_env);
                        if E_residual(i) >= E_tx
                            E_residual(i) = E_residual(i) - E_tx;
                            if succ_matrix(i, numNodes+1)
                                del_this_round = del_this_round + reports_carried;
                                hop_delay = (wsn_env.packetSize / R_bit) + T_proc + (d_bs / c);
                                delay_sum_this_round = delay_sum_this_round + report_delays(i) + reports_carried * hop_delay;
                            end
                        else
                            E_residual(i) = 0;
                        end
                    else
                        E_residual(i) = 0;
                    end
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