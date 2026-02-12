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

interface VaultValuePoint {
  epoch: number;
  value: number;
}

interface VaultValueChartProps {
  data: VaultValuePoint[];
}

export function VaultValueChart({ data }: VaultValueChartProps) {
  return (
    <ResponsiveContainer width="100%" height={280}>
      <RechartsAreaChart data={data}>
        <defs>
          <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="var(--primary)" stopOpacity={0.3} />
            <stop offset="95%" stopColor="var(--primary)" stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
        <XAxis
          dataKey="epoch"
          stroke="var(--muted-foreground)"
          fontSize={11}
          tickFormatter={(v) => `E${v}`}
        />
        <YAxis
          stroke="var(--muted-foreground)"
          fontSize={11}
          tickFormatter={(v) => `${v} USDC`}
        />
        <Tooltip
          contentStyle={{
            background: "var(--card)",
            border: "1px solid var(--border)",
            borderRadius: "var(--radius)",
          }}
          labelStyle={{ color: "var(--foreground)" }}
          formatter={(value: number) => [`${value} USDC`, "Vault Value"]}
          labelFormatter={(label) => `Epoch ${label}`}
        />
        <Area
          type="monotone"
          dataKey="value"
          stroke="var(--primary)"
          strokeWidth={2}
          fill="url(#colorValue)"
          name="Vault Value (USDC)"
        />
      </RechartsAreaChart>
    </ResponsiveContainer>
  );
}
