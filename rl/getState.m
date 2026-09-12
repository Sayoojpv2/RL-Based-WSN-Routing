% rl/getState.m
function state_idx = getState(curr, E_residual, E_initial, node_load, lq_matrix, wsn_env, neighborRange)
    % Evaluates the CURRENT node's situation before taking an action.
    % 5 discrete variables (3 levels each) -> 3^5 = 243 states.
    %
    % State Features:
    %   s1: Current node residual energy level (1: Low, 2: Med, 3: High)
    %   s2: Candidate / neighbor residual energy level (1: Low, 2: Med, 3: High)
    %   s3: Link-quality condition level (1: Poor, 2: Med, 3: Good)
    %   s4: Forwarding-load level (1: Low, 2: Med, 3: High)
    %   s5: Progress / proximity toward BS (1: Far, 2: Mid, 3: Close)
    %
    % Returns state_idx in range [1, 243].

    numNodes = wsn_env.numNodes;

    % -------------------------------------------------------------
    % 1. Current Node Residual Energy Level
    % -------------------------------------------------------------
    if curr == numNodes + 1
        s1 = 3; % Base Station has infinite energy
    else
        e_ratio = E_residual(curr) / max(1e-6, E_initial);
        if e_ratio > 0.66
            s1 = 3; % High
        elseif e_ratio > 0.33
            s1 = 2; % Medium
        else
            s1 = 1; % Low
        end
    end

    % -------------------------------------------------------------
    % 2. Candidate / Neighbor Residual Energy Level
    % -------------------------------------------------------------
    if curr == numNodes + 1
        s2 = 3;
    else
        d_curr_bs = sqrt((wsn_env.X(curr) - wsn_env.BS_X)^2 + (wsn_env.Y(curr) - wsn_env.BS_Y)^2);
        cand_energies = [];
        for j = 1:numNodes
            if curr ~= j && E_residual(j) > 0
                dist_j = sqrt((wsn_env.X(curr) - wsn_env.X(j))^2 + (wsn_env.Y(curr) - wsn_env.Y(j))^2);
                if dist_j <= neighborRange
                    dist_j_bs = sqrt((wsn_env.X(j) - wsn_env.BS_X)^2 + (wsn_env.Y(j) - wsn_env.BS_Y)^2);
                    if dist_j_bs < d_curr_bs % forward neighbor
                        cand_energies(end+1) = E_residual(j) / max(1e-6, E_initial);
                    end
                end
            end
        end

        if isempty(cand_energies)
            if d_curr_bs <= neighborRange
                avg_cand_e = 1.0; % Can reach BS directly
            else
                avg_cand_e = 0.0;
            end
        else
            avg_cand_e = mean(cand_energies);
        end

        if avg_cand_e > 0.66
            s2 = 3; % High
        elseif avg_cand_e > 0.33
            s2 = 2; % Medium
        else
            s2 = 1; % Low
        end
    end

    % -------------------------------------------------------------
    % 3. Current Link-Quality Condition Level
    % -------------------------------------------------------------
    if curr == numNodes + 1
        s3 = 3;
    else
        valid_lqs = [];
        for j = 1:numNodes
            if curr ~= j && E_residual(j) > 0
                dist_j = sqrt((wsn_env.X(curr) - wsn_env.X(j))^2 + (wsn_env.Y(curr) - wsn_env.Y(j))^2);
                if dist_j <= neighborRange
                    valid_lqs(end+1) = lq_matrix(curr, j);
                end
            end
        end
        dist_bs = sqrt((wsn_env.X(curr) - wsn_env.BS_X)^2 + (wsn_env.Y(curr) - wsn_env.BS_Y)^2);
        if dist_bs <= neighborRange
            valid_lqs(end+1) = lq_matrix(curr, numNodes + 1);
        end

        if isempty(valid_lqs)
            avg_lq = 0;
        else
            avg_lq = mean(valid_lqs);
        end

        if avg_lq > 0.70
            s3 = 3; % Good
        elseif avg_lq > 0.40
            s3 = 2; % Medium
        else
            s3 = 1; % Poor
        end
    end

    % -------------------------------------------------------------
    % 4. Current Node Forwarding Load Level
    % -------------------------------------------------------------
    if curr == numNodes + 1
        s4 = 1; % BS has no forwarding congestion penalty
    else
        nl = node_load(curr);
        if nl <= 1
            s4 = 1; % Low
        elseif nl <= 4
            s4 = 2; % Medium
        else
            s4 = 3; % High
        end
    end

    % -------------------------------------------------------------
    % 5. Current Node Progress / Proximity Toward Base Station
    % -------------------------------------------------------------
    if curr == numNodes + 1
        s5 = 3; % At Base Station
    else
        d_curr_bs = sqrt((wsn_env.X(curr) - wsn_env.BS_X)^2 + (wsn_env.Y(curr) - wsn_env.BS_Y)^2);
        prog_ratio = d_curr_bs / max(1, wsn_env.riverLength);
        if prog_ratio <= 0.33
            s5 = 3; % Close (Good progress)
        elseif prog_ratio <= 0.66
            s5 = 2; % Medium progress
        else
            s5 = 1; % Far (Poor progress)
        end
    end

    % -------------------------------------------------------------
    % Convert (s1, s2, s3, s4, s5) to 1-based index in 1..243
    % -------------------------------------------------------------
    state_idx = (s1 - 1)*81 + (s2 - 1)*27 + (s3 - 1)*9 + (s4 - 1)*3 + s5;
    state_idx = max(1, min(243, state_idx));
end
