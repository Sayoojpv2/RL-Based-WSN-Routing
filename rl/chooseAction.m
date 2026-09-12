% rl/chooseAction.m
function action = chooseAction(curr_state_idx, candidates, Q, epsilon)
    % Epsilon-greedy selection of a next-hop candidate.
    %
    % Inputs:
    %   curr_state_idx : current RL state, integer 1..numStates (e.g. 1..243)
    %   candidates     : valid next-hop action IDs, subset of 1..numActions (e.g. 1..51)
    %   Q              : Q-table, numStates x numActions
    %   epsilon        : exploration probability
    %
    % Output:
    %   action         : selected candidate action ID, or -1 if no candidate

    if isempty(candidates)
        action = -1;
        return;
    end

    % Sanitize candidate IDs to valid action column indices
    candidates = candidates(:)';
    candidates = candidates(candidates >= 1 & ...
                            candidates <= size(Q, 2) & ...
                            candidates == round(candidates));

    if isempty(candidates)
        action = -1;
        return;
    end

    % Clamp state index to valid row range
    curr_state_idx = max(1, min(size(Q, 1), round(curr_state_idx)));

    % Epsilon-greedy selection
    if rand() < epsilon
        % Exploration: select uniformly at random among valid filtered candidates
        action = candidates(randi(numel(candidates)));
        return;
    end

    % Exploitation: select candidate with highest Q-value
    q_values = Q(curr_state_idx, candidates);
    max_q = max(q_values);

    % Robust tie-breaking with numerical tolerance
    best_mask = abs(q_values - max_q) < 1e-9;
    best_candidates = candidates(best_mask);

    if isempty(best_candidates)
        best_candidates = candidates;
    end

    action = best_candidates(randi(numel(best_candidates)));
end