# The CEO protocol V2

## Proposals from agent can get stale (covered)
When an agent makes a proposal, maybe new capital is added or some is removed, so the proposal execution can fail
It's very important to make so the proposals are not tied to numbers but to % so it will execute no matter what amounts are there.

## there should be the possibility to make more complex strategies, not only rebalances. (covered)
eg: deposit usdc on morpho, getting morphUSD and depositing them in another protocol, and so on
// note: the external protocols that are not vault, should be added carefully and there should be a list of function selector for each protcol (eg supply ecc) that is allowed in CEOVaultV2


## the CEO role is blocking the protocol (covered)
the CEO is the only allowed to execute the strategy, but it shouldnt be like that. anyone should be able to do it, as a relayer, in exchange of fee.
The CEO agent should have less power, maybe just having more influence in the voting system 


## Agents rewards are too complicated (covered)
there should just be a entry fee that is distributed to top 10 agents. this way the loop is smaller and easier, instantly rewarding. the best job the agent do, the more users enter, the more agents earn. there can be other mechanics agents can earn, like executing actions as relayer

## CEO token sit there, and has no utilization (covered - used for voting power - consider some burning mechanism in future)
we can choose to burn it for every vote, or use it as an agent voting token, that increases the voting power of agents, it can also act as a multiplier for rewards

## Capital can be deposited and many days can pass before it's deployed (covered)
capital should never be idle in the vault. there can be a hook that is triggered or an automation that deploy the capital immediately. there can be the current strategy that split the capital in parts and deposit in the vault according to percentages

## There is a design error in the 8004 registration. 
registering agent should call the registry and handle the registration automatically

## Agents have extreme difficulty to create strategies, proposals and actions
Agents often do mistakes when elaborating complex strategies




