// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICEOVaultV2} from "../ICEOVaultV2.sol";

/// @title Top10SnapshotLib
/// @notice Library for snapshotting top 10 agents by score for fee distribution
library Top10SnapshotLib {
    /// @dev Snapshot top 10 agents by score for an epoch. Called at settle before advancing.
    /// @param s_agentList Enumerable list of all registered agents
    /// @param s_agents Agent registry mapping
    /// @param s_top10Snapshot Mapping of epoch to top 10 snapshot (modified in place)
    /// @param epoch Epoch to snapshot for
    function takeTop10Snapshot(
        address[] storage s_agentList,
        mapping(address => ICEOVaultV2.Agent) storage s_agents,
        mapping(uint256 => ICEOVaultV2.Top10Snapshot) storage s_top10Snapshot,
        uint256 epoch
    ) internal {
        address[10] memory top;
        uint256 topCount;
        uint256 len = s_agentList.length;

        for (uint256 i = 0; i < len; i++) {
            address a = s_agentList[i];
            if (!s_agents[a].active) continue;
            int256 sc = s_agents[a].score;

            if (topCount < 10) {
                top[topCount] = a;
                topCount++;
                uint256 j = topCount - 1;
                while (j > 0 && s_agents[top[j]].score > s_agents[top[j - 1]].score) {
                    (top[j], top[j - 1]) = (top[j - 1], top[j]);
                    j--;
                }
            } else if (sc > s_agents[top[9]].score) {
                top[9] = a;
                uint256 j = 9;
                while (j > 0 && s_agents[top[j]].score > s_agents[top[j - 1]].score) {
                    (top[j], top[j - 1]) = (top[j - 1], top[j]);
                    j--;
                }
            }
        }

        ICEOVaultV2.Top10Snapshot storage snap = s_top10Snapshot[epoch];
        snap.count = uint8(topCount);
        for (uint256 i = 0; i < topCount; i++) {
            snap.agents[i] = top[i];
        }
    }
}
