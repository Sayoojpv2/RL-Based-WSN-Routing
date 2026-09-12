function E_tx = tx_energy(k, d, env)
    % TX_ENERGY Calculates transmission energy using the first-order radio model.
    %
    % Inputs:
    %   k   - Packet size (bits)
    %   d   - Transmission distance (meters)
    %   env - WSN environment struct containing radio parameters
    %         Requires fields: E_elec, E_fs, E_mp, d0
    %
    % Output:
    %   E_tx - Energy consumed during transmission (Joules)
    %
    % The model piecewise selects between free-space (d^2) and 
    % multi-path fading (d^4) models based on the threshold distance (d0).

    if d < env.d0
        % Free-space propagation model (short distance)
        E_tx = k * (env.E_elec + env.E_fs * (d^2));
    else
        % Multi-path fading propagation model (long distance)
        E_tx = k * (env.E_elec + env.E_mp * (d^4));
    end
end
