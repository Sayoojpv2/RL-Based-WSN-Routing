% rl/updateQTable.m
function Q = updateQTable(Q, state_idx, action, reward, next_state_max_q, alpha, gamma)
    % updateQTable - Standard tabular Q-learning Bellman optimality update.
    %
    % Q(s, a) = Q(s, a) + alpha * [reward + gamma * max_a' Q(s', a') - Q(s, a)]
    %
    % Inputs:
    %   Q                - Current Q-table (numStates x numActions)
    %   state_idx        - State index (1..numStates)
    %   action           - Chosen action index (1..numActions)
    %   reward           - Scalar reward signal
    %   next_state_max_q - max_a' Q(s', a') from lookahead, or 0 if terminal
    %   alpha            - Learning rate
    %   gamma            - Discount factor

    if action < 1 || action > size(Q, 2) || state_idx < 1 || state_idx > size(Q, 1)
        return;
    end

    if isnan(reward) || isinf(reward)
        return;
    end

    current_q = Q(state_idx, action);
    td_target = reward + gamma * next_state_max_q;
    new_q = current_q + alpha * (td_target - current_q);

    % Guard against any numerical anomalies
    if ~isnan(new_q) && ~isinf(new_q)
        Q(state_idx, action) = new_q;
    end
end
