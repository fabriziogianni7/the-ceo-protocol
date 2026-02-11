"use client";

import {
  PieChart as RechartsPieChart,
  Pie,
  Cell,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";

const data = [
  { name: "Category A", value: 400, color: "var(--primary)" },
  { name: "Category B", value: 300, color: "var(--accent)" },
  { name: "Category C", value: 200, color: "var(--ring)" },
  { name: "Category D", value: 278, color: "#9c6ade" },
  { name: "Category E", value: 189, color: "#6c6c89" },
];

export function PieChart() {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <RechartsPieChart>
        <Pie
          data={data}
          cx="50%"
          cy="50%"
          innerRadius={60}
          outerRadius={100}
          paddingAngle={2}
          dataKey="value"
          stroke="var(--card)"
          strokeWidth={2}
        >
          {data.map((entry, index) => (
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
        />
        <Legend />
      </RechartsPieChart>
    </ResponsiveContainer>
  );
}
