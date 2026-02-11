"use client";

import {
  PieChart as RechartsPieChart,
  Pie,
  Cell,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";

const COLORS = ["var(--primary)", "var(--accent)", "var(--ring)", "#9c6ade"];

interface CompositionItem {
  name: string;
  value: number;
  percent: number;
}

interface VaultCompositionChartProps {
  data: CompositionItem[];
}

export function VaultCompositionChart({ data }: VaultCompositionChartProps) {
  const chartData = data.map((d) => ({
    name: d.name,
    value: d.value,
    percent: d.percent,
    color: COLORS[data.indexOf(d) % COLORS.length],
  }));

  return (
    <ResponsiveContainer width="100%" height={200}>
      <RechartsPieChart>
        <Pie
          data={chartData}
          cx="50%"
          cy="50%"
          innerRadius={50}
          outerRadius={80}
          paddingAngle={2}
          dataKey="value"
          stroke="var(--card)"
          strokeWidth={2}
        >
          {chartData.map((entry, index) => (
            <Cell key={`cell-${index}`} fill={entry.color} />
          ))}
        </Pie>
        <Tooltip
          contentStyle={{
            background: "var(--card)",
            border: "1px solid var(--border)",
            borderRadius: "var(--radius)",
          }}
          labelStyle={{ color: "var(--foreground)" }}
          formatter={(value: number, name: string) => [
            `${value} MON`,
            name,
          ]}
        />
        <Legend />
      </RechartsPieChart>
    </ResponsiveContainer>
  );
}
