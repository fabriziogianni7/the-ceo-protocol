"use client";

import {
  AreaChart as RechartsAreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import { MOCK_VAULT_HISTORY } from "@/lib/mock-data";

export function VaultValueChart() {
  return (
    <ResponsiveContainer width="100%" height={280}>
      <RechartsAreaChart data={MOCK_VAULT_HISTORY}>
        <defs>
          <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="var(--primary)" stopOpacity={0.3} />
            <stop offset="95%" stopColor="var(--primary)" stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
        <XAxis
          dataKey="date"
          stroke="var(--muted-foreground)"
          fontSize={11}
          tickFormatter={(v) => {
            const d = new Date(v);
            return `${d.getMonth() + 1}/${d.getDate()}`;
          }}
        />
        <YAxis
          stroke="var(--muted-foreground)"
          fontSize={11}
          tickFormatter={(v) => `${v} MON`}
        />
        <Tooltip
          contentStyle={{
            background: "var(--card)",
            border: "1px solid var(--border)",
            borderRadius: "var(--radius)",
          }}
          labelStyle={{ color: "var(--foreground)" }}
          formatter={(value: number) => [`${value} MON`, "Vault Value"]}
          labelFormatter={(label) => new Date(label).toLocaleDateString()}
        />
        <Area
          type="monotone"
          dataKey="value"
          stroke="var(--primary)"
          strokeWidth={2}
          fill="url(#colorValue)"
          name="Vault Value (MON)"
        />
      </RechartsAreaChart>
    </ResponsiveContainer>
  );
}
