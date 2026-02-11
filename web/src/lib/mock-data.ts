/**
 * Mock data for CEO Protocol — will be replaced with contract integration
 */

export const MOCK_VAULT_HISTORY = [
  { date: "2025-01-01", value: 4.2, mon: 3.1, usdc: 1.1 },
  { date: "2025-01-08", value: 5.1, mon: 3.8, usdc: 1.3 },
  { date: "2025-01-15", value: 4.8, mon: 3.5, usdc: 1.3 },
  { date: "2025-01-22", value: 5.4, mon: 3.9, usdc: 1.5 },
  { date: "2025-01-29", value: 6.2, mon: 4.5, usdc: 1.7 },
  { date: "2025-02-05", value: 5.9, mon: 4.1, usdc: 1.8 },
  { date: "2025-02-10", value: 7.1, mon: 5.0, usdc: 2.1 },
];

export const MOCK_VAULT_STATE = {
  totalValue: 7.1,
  totalAssets: "7100000000000000000",
  totalShares: "6800000000000000000",
  monBalance: 5.0,
  usdcBalance: 2.1,
  composition: [
    { name: "MON", value: 5.0, percent: 70 },
    { name: "USDC", value: 2.1, percent: 30 },
  ],
};

export const MOCK_LEADERBOARD = [
  { address: "0x1234...5678", score: 42, isCEO: true },
  { address: "0xabcd...ef01", score: 38, isCEO: false },
  { address: "0x9876...5432", score: 31, isCEO: false },
  { address: "0xfedc...ba09", score: 25, isCEO: false },
];

export const MOCK_PROPOSALS = [
  { id: 0, votesFor: 120, votesAgainst: 45, target: "70% MON, 30% USDC" },
  { id: 1, votesFor: 85, votesAgainst: 98, target: "50% MON, 50% USDC" },
];

export const MOCK_EPOCH = {
  current: 12,
  votingDeadline: Date.now() / 1000 + 86400 * 0.5,
  rebalanced: false,
};
