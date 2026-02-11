"use client";

import {
  LineChart as RechartsLineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";

const data = [
  { name: "Jan", uv: 4000, pv: 2400 },
  { name: "Feb", uv: 3000, pv: 1398 },
  { name: "Mar", uv: 2000, pv: 9800 },
  { name: "Apr", uv: 2780, pv: 3908 },
  { name: "May", uv: 1890, pv: 4800 },
  { name: "Jun", uv: 2390, pv: 3800 },
];

export function LineChart() {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <RechartsLineChart data={data}>
        <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
        <XAxis dataKey="name" stroke="var(--muted-foreground)" fontSize={12} />
        <YAxis stroke="var(--muted-foreground)" fontSize={12} />
        <Tooltip
          contentStyle={{
            background: "var(--card)",
            border: "1px solid var(--border)",
            borderRadius: "var(--radius)",
          }}
          labelStyle={{ color: "var(--foreground)" }}
        />
        <Legend />
        <Line
          type="monotone"
          dataKey="uv"
          stroke="var(--primary)"
          strokeWidth={2}
          dot={{ fill: "var(--primary)" }}
          name="Series A"
        />
        <Line
          type="monotone"
          dataKey="pv"
          stroke="var(--accent)"
          strokeWidth={2}
          dot={{ fill: "var(--accent)" }}
          name="Series B"
        />
      </RechartsLineChart>
    </ResponsiveContainer>
  );
}
