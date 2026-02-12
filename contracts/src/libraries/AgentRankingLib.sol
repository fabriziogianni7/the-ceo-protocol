// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICEOVault} from "../ICEOVault.sol";

/// @title AgentRankingLib
/// @notice External library for ranking active CEOVault agents
library AgentRankingLib {
    /// @notice Return top and second active agents by score
    /// @param s_agentList Enumerable list of all registered agents
    /// @param s_agents Agent registry mapping
    /// @return topAddr Highest-scoring active agent (or zero address)
    /// @return secondAddr Second highest-scoring active agent (or zero address)
    function getTopTwoAgents(
        address[] storage s_agentList,
        mapping(address => ICEOVault.Agent) storage s_agents
    ) external view returns (address topAddr, address secondAddr) {
        int256 topScore = type(int256).min;
        int256 secondScore = type(int256).min;

        uint256 len = s_agentList.length;
        for (uint256 i = 0; i < len; i++) {
            address agentAddr = s_agentList[i];
            if (!s_agents[agentAddr].active) continue;

            int256 score = s_agents[agentAddr].score;
            if (score > topScore) {
                secondAddr = topAddr;
                secondScore = topScore;
                topAddr = agentAddr;
                topScore = score;
            } else if (score > secondScore) {
                secondAddr = agentAddr;
                secondScore = score;
            }
        }
    }

    /// @notice Return active agents sorted by descending score
    /// @param s_agentList Enumerable list of all registered agents
    /// @param s_agents Agent registry mapping
    /// @return rankedAgents Sorted agent addresses (active only)
    /// @return rankedScores Sorted agent scores aligned with rankedAgents
    function getLeaderboard(
        address[] storage s_agentList,
        mapping(address => ICEOVault.Agent) storage s_agents
    ) external view returns (address[] memory rankedAgents, int256[] memory rankedScores) {
        uint256 len = s_agentList.length;
        rankedAgents = new address[](len);
        rankedScores = new int256[](len);

        uint256 count;
        for (uint256 i = 0; i < len; i++) {
            address agentAddr = s_agentList[i];
            if (!s_agents[agentAddr].active) continue;

            rankedAgents[count] = agentAddr;
            rankedScores[count] = s_agents[agentAddr].score;
            count++;
        }

        assembly {
            mstore(rankedAgents, count)
            mstore(rankedScores, count)
        }

        for (uint256 i = 1; i < count; i++) {
            int256 keyScore = rankedScores[i];
            address keyAddr = rankedAgents[i];
            uint256 j = i;
            while (j > 0 && rankedScores[j - 1] < keyScore) {
                rankedScores[j] = rankedScores[j - 1];
                rankedAgents[j] = rankedAgents[j - 1];
                j--;
            }
            rankedScores[j] = keyScore;
            rankedAgents[j] = keyAddr;
        }
    }
}
