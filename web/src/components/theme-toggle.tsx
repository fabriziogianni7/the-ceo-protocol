"use client";

import { useEffect, useState } from "react";

export function ThemeToggle() {
  const [state, setState] = useState<{
    mounted: boolean;
    theme: "light" | "dark";
  }>({ mounted: false, theme: "light" });

  useEffect(() => {
    const stored = localStorage.getItem("theme") as "light" | "dark" | null;
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    const initial = stored ?? (prefersDark ? "dark" : "light");
    document.documentElement.classList.toggle("dark", initial === "dark");
    const id = setTimeout(() => setState({ mounted: true, theme: initial }), 0);
    return () => clearTimeout(id);
  }, []);

  const toggle = () => {
    const next = state.theme === "light" ? "dark" : "light";
    setState((s) => ({ ...s, theme: next }));
    document.documentElement.classList.toggle("dark", next === "dark");
    localStorage.setItem("theme", next);
  };

  if (!state.mounted) return null;

  return (
    <button
      type="button"
      onClick={toggle}
      className="rounded-[var(--radius)] p-2 hover:bg-[var(--muted)] transition-colors"
      aria-label={`Switch to ${state.theme === "light" ? "dark" : "light"} mode`}
    >
      {state.theme === "light" ? (
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z" />
        </svg>
      ) : (
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2" />
          <path d="M12 20v2" />
          <path d="m4.93 4.93 1.41 1.41" />
          <path d="m17.66 17.66 1.41 1.41" />
          <path d="M2 12h2" />
          <path d="M20 12h2" />
          <path d="m6.34 17.66-1.41 1.41" />
          <path d="m19.07 4.93-1.41 1.41" />
        </svg>
      )}
    </button>
  );
}
