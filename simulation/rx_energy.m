function E_rx = rx_energy(k, env)
    % RX_ENERGY Calculates reception energy using the first-order radio model.
    %
    % Inputs:
    %   k   - Packet size (bits)
    %   env - WSN environment struct containing radio parameters
    %         Requires fields: E_elec
    %
    % Output:
    %   E_rx - Energy consumed during reception (Joules)
    %
    % Reception energy is purely dependent on the number of bits processed
    % by the receiver electronics.

    E_rx = k * env.E_elec;
end
