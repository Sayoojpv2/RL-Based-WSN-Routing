# RL-Based Adaptive WSN Routing (Part 1: Routing Benchmark & Evaluation)

A MATLAB simulation framework for energy-efficient, fault-tolerant routing in linear/elongated Wireless Sensor Networks (WSNs) deployed in river-channel environments. 

This repository implements, evaluates, and benchmarks **RL-Hybrid** (a Reinforcement Learning-based adaptive clustering and multi-hop routing protocol) against classical WSN routing baselines (**LEACH**, **DEEC**, and **PEGASIS**) under common channel fading conditions and abrupt intermediate relay node failure.

---

## 1. Simulation Setup & Scenario Specifications

All four protocols are evaluated under strictly identical topology realizations, channel conditions, packet sizes, and radio energy parameters:

| Parameter | Value | Description |
| :--- | :--- | :--- |
| **Network Size** | 50 sensor nodes | Randomly distributed along the river channel |
| **Deployment Area** | 600 m × 50 m | Elongated river-channel corridor |
| **Base Station (BS)** | $(X = 600\text{ m},\, Y = 25\text{ m})$ | Fixed at downstream outlet |
| **Initial Energy** | 2.0 Joules / node | 100.0 Joules total network energy |
| **Packet Size** | 4,000 bits | Data packet payload |
| **Simulation Duration** | 1,000 rounds | Evaluated across 5 random seeds (42, 43, 44, 45, 46) |
| **Radio Model** | First-Order Radio Model | $E_{\text{elec}} = 50\text{ nJ/bit}$, $E_{\text{DA}} = 5\text{ nJ/bit}$ |
| **Amplifier Parameters** | Free-space & Multipath | $E_{\text{fs}} = 10\text{ pJ/bit/m}^2$, $E_{\text{mp}} = 0.0013\text{ pJ/bit/m}^4$, $d_0 = 87.7\text{ m}$ |
| **Channel Model** | Distance-dependent path loss + fading | Common pre-generated channel quality and packet reception matrices |
| **Failure Event** | Relay nodes [15, 25, 35] fail at Round 500 | Controlled mid-network relay severance to evaluate fault tolerance |

Transmission energy follows the standard piecewise first-order model:
```math
E_{\text{tx}}(k, d) = \begin{cases} 
k \cdot (E_{\text{elec}} + E_{\text{fs}} \cdot d^2), & d < d_0 \\
k \cdot (E_{\text{elec}} + E_{\text{mp}} \cdot d^4), & d \ge d_0 
\end{cases}
```
Reception energy:
```math
E_{\text{rx}}(k) = k \cdot E_{\text{elec}}
```

---

## 2. Protocols Evaluated

1. **LEACH (Low-Energy Adaptive Clustering Hierarchy)**  
   Classical distributed clustering protocol where nodes self-elect as Cluster Heads (CHs) based on a probabilistic threshold. Member nodes transmit to CHs, which aggregate and transmit directly to the distant Base Station ($d^4$ multipath drain).

2. **DEEC (Distributed Energy-Efficient Clustering)**  
   Heterogeneous-aware clustering where CH election probability is weighted by residual energy relative to average network energy. Like LEACH, CHs transmit directly to the Base Station.

3. **PEGASIS (Power-Efficient Gathering in Sensor Information Systems)**  
   Greedy chain-construction protocol where nodes transmit only to nearest neighbors. A round-robin chain leader aggregates all node reports into a single packet and transmits to the Base Station.

4. **RL-Hybrid (Proposed Reinforcement Learning Method)**  
   A hybrid adaptive clustering and multi-hop routing framework governed by tabular Q-learning:
   - **State Space $S$**: Discretized based on node residual energy level, distance to Base Station, and local link quality.
   - **Action Space $A$**: Selection among alive candidate next-hop forwarders (neighbor relays within transmission range or direct Base Station when reachable).
   - **Reward Function $R(s, a)$**: Formulated to reward energy preservation, distance progress toward BS, and high channel delivery probability, while penalizing transmission delay and node death/unreachable hops.
   - **Q-Value Update**: Standard Bellman optimality equation:
     ```math
     Q(s, a) \leftarrow Q(s, a) + \alpha \left[ R(s, a) + \gamma \max_{a'} Q(s', a') - Q(s, a) \right]
     ```
   - **Fault Adaptation**: When intermediate relay nodes [15, 25, 35] abruptly fail at round 500, RL-Hybrid detects degraded delivery and updates state-action values to route packets around the severed corridor.

---

## 3. Validated Performance Results (5-Seed Summary)

All metrics report the mean $\pm$ standard deviation calculated across the 5 validated seeds (Seeds 42, 43, 44, 45, and 46):

| Metric | LEACH | DEEC | PEGASIS | RL-Hybrid (Proposed) |
| :--- | :---: | :---: | :---: | :---: |
| **First Node Dead (FND)** | $23.2 \pm 2.3$ rounds | $26.4 \pm 7.9$ rounds | $74.0 \pm 71.7$ rounds | **$475.4 \pm 55.0$ rounds** |
| **Half Nodes Dead (HND)** | $105.0 \pm 36.8$ rounds | $116.2 \pm 46.1$ rounds | **$772.0 \pm 161.2$ rounds** | $645.0 \pm 49.2$ rounds |
| **Last Node Dead (LND)** | $908$ ($1/5$ seeds) | $814$ ($2/5$ seeds) | $>1000$ rounds | $>1000$ rounds |
| **Final Alive Nodes (Round 1000)** | $6.2 \pm 5.8$ | $3.8 \pm 5.0$ | $23.4 \pm 3.3$ | $14.0 \pm 14.9$ |
| **Packet Delivery Ratio (PDR)** | $62.79\% \pm 5.24\%$ | $57.13\% \pm 3.93\%$ | $29.23\% \pm 1.53\%$ | **$86.10\% \pm 0.53\%$** |
| **Successfully Delivered Reports** | $9,260 \pm 2,968$ | $8,018 \pm 2,835$ | $10,349 \pm 542$ | **$31,889 \pm 5,318$** |
| **Total Routing Energy Consumed** | $97.0 \pm 2.7$ J | $98.7 \pm 1.8$ J | $70.8 \pm 5.4$ J | $90.6 \pm 12.7$ J |
| **Energy per Delivered Report** | $0.0114 \pm 0.0039$ J | $0.0136 \pm 0.0050$ J | $0.0069 \pm 0.0008$ J | **$0.0029 \pm 0.0007$ J** |
| **Energy Efficiency** | $96.1 \pm 33.0$ rep/J | $81.6 \pm 30.5$ rep/J | $147.3 \pm 18.6$ rep/J | **$365.9 \pm 129.4$ rep/J** |

### Key Findings & Nuances
- **Highest Packet Delivery Ratio**: RL-Hybrid achieves $86.10\% \pm 0.53\%$ PDR, significantly higher than LEACH ($62.79\%$), DEEC ($57.13\%$), and PEGASIS ($29.23\%$).
- **Highest Energy Efficiency**: RL-Hybrid delivers $365.9 \pm 129.4$ reports/J compared to $96.1$ for LEACH, $81.6$ for DEEC, and $147.3$ for PEGASIS.
- **Lowest Cost per Report**: RL-Hybrid requires $0.0029 \pm 0.0007$ J/delivered report (vs. $0.0114$ J for LEACH and $0.0069$ J for PEGASIS).
- **Longest Full-Network Stability (FND)**: RL-Hybrid preserves all 50 nodes intact until round $475.4 \pm 55.0$ (vs. round $23.2$ for LEACH and $74.0$ for PEGASIS).
- **HND Trade-off**: PEGASIS achieves superior HND ($772.0 \pm 161.2$ rounds) because its chain aggregates all node observations into a single packet per round, severely reducing transmissions but resulting in high packet loss ($29.23\%$ PDR) when chain links fail.

---

## 4. Repository Structure

```
RL-Based-WSN-Routing/
├── main.m                         # Master entry point script
├── run_full_evaluation.m          # Master 5-seed evaluation runner
├── run_experiments.m              # Multi-run experiment suite
├── print_comprehensive_metrics.m  # Console statistical summary printer
├── generate_seed_validation.m     # Seed validation reporter
├── protocols/
│   ├── LEACH.m                    # LEACH protocol implementation
│   ├── DEEC.m                     # DEEC protocol implementation
│   ├── PEGASIS.m                  # PEGASIS protocol implementation
│   └── RL_Hybrid.m                # Proposed RL-Hybrid protocol
├── simulation/
│   ├── generate_scenario.m        # 50-node river scenario and fading generator
│   ├── tx_energy.m                # Radio transmission energy calculation
│   └── rx_energy.m                # Radio reception energy calculation
├── rl/
│   ├── initializeQTable.m         # Q-table initialization
│   ├── getState.m                 # State discretization
│   ├── chooseAction.m             # Action selection policy
│   ├── calculateReward.m          # Composite reward calculation
│   ├── updateQTable.m             # Q-learning Bellman update
│   └── README.txt                 # RL engine notes
└── analysis/
    ├── all_runs_raw.mat           # Validated 5-seed 1000-round trajectory dataset
    ├── final_results.m            # Script to generate publication dashboard & table
    ├── final_plots_dashboard.png  # Figure 1: 6-subplot trajectory dashboard
    ├── final_plots_dashboard.pdf  # Figure 1: Vector PDF
    ├── final_comparison_table.png # Figure 2: Statistical summary table
    ├── final_comparison_table.pdf # Figure 2: Vector PDF
    ├── seed_validation.txt        # Per-seed verification output
    ├── compare_protocols.m        # Comparative plotting utility
    ├── LEACH_results.mat          # Averaged LEACH trajectories
    ├── DEEC_results.mat           # Averaged DEEC trajectories
    ├── PEGASIS_results.mat        # Averaged PEGASIS trajectories
    └── RL_HAR_results.mat         # Averaged RL-Hybrid trajectories
```

---

## 5. How to Reproduce Results & Figures

### Quick Start (View Existing Validated Results)
To immediately display the publication dashboard and summary comparison table from the pre-computed 5-seed dataset:
```matlab
% In MATLAB command window:
main
% Select Option 1 (or press Enter)
```
Or directly run:
```matlab
addpath('analysis');
final_results;
```
This generates and displays:
1. `results/figures/final_plots_dashboard.png` (Network lifetime, PDR trajectory, energy efficiency, energy per report, failure recovery, unified legend).
2. `results/figures/final_comparison_table.png` (Complete numerical table and statistical findings).

### Verify Numerical Integrity Across Seeds
To inspect the per-seed breakdown and verify data source integrity:
```matlab
generate_seed_validation;
print_comprehensive_metrics;
```

### Re-run the Full 5-Seed Simulation from Scratch
To completely re-simulate all 5 seeds (Seeds 42–46) across 1,000 rounds from scratch:
```matlab
run_full_evaluation;
```
*Note: Full simulation evaluates 50 nodes × 4 protocols × 1,000 rounds × 5 seeds and takes approximately 5–10 minutes depending on hardware.*

---

## 6. Requirements
- MATLAB R2020a or later
- No proprietary toolboxes required (all algorithms, channel modeling, and RL engines are implemented in native MATLAB code).

