RL-HYBRID MODULES

Contents:
rl\initializeQTable.m
rl\getState.m
rl\chooseAction.m
rl\calculateReward.m
rl\updateQTable.m
protocols\RL_Hybrid.m

The RL_Hybrid.m protocol utilizes these modules for adaptive multi-hop Q-learning routing.
Reaching a cluster head (CH) is treated as an intermediate transition using the CH next-state max-Q value.
All scripts use project-relative paths, allowing execution directly from the repository root.
Phase-2 RL-Hybrid routing remains localized: the Base Station is a direct action only when within range,
while alive local sensor nodes act as intermediate relays.
