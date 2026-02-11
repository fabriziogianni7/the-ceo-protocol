"use client";

import { useEffect, useState } from "react";
import { FlickeringGrid } from "@/components/ui/flickering-grid";

/**
 * Theme-aware FlickeringGrid background.
 * Resolves --primary from CSS variables so it adapts to light/dark mode.
 */
export function FlickeringGridBackground() {
  const [color, setColor] = useState("#5423e7");

  useEffect(() => {
    const update = () => {
      const v = getComputedStyle(document.documentElement)
        .getPropertyValue("--primary")
        .trim();
      setColor(v || "#5423e7");
    };
    update();

    const observer = new MutationObserver(update);
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    });
    return () => observer.disconnect();
  }, []);

  return (
    <div
      className="fixed inset-0 z-0 overflow-hidden"
      aria-hidden="true"
    >
      <div className="absolute inset-0 bg-[var(--background)]" />
      <FlickeringGrid
        className="absolute inset-0 size-full"
        squareSize={4}
        gridGap={6}
        color={color}
        maxOpacity={0.15}
        flickerChance={0.08}
      />
    </div>
  );
}
