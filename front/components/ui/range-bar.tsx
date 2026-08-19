"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

export interface RangeBarProps {
  min: number;
  max: number;
  bandStart: number;
  bandEnd: number;
  value: number;
  lowLabel?: string;
  highLabel?: string;
  className?: string;
  id?: string;
  markerClassName?: string;
}

function pct(value: number, min: number, max: number): number {
  if (max <= min) return 0;
  return Math.min(100, Math.max(0, ((value - min) / (max - min)) * 100));
}

export function RangeBar({
  min,
  max,
  bandStart,
  bandEnd,
  value,
  lowLabel,
  highLabel,
  className,
  id,
  markerClassName,
}: RangeBarProps) {
  const markerPct = pct(value, min, max);
  const bandLeft = pct(bandStart, min, max);
  const bandRight = pct(bandEnd, min, max);

  return (
    <div className={cn("w-full", className)} id={id}>
      <div className="relative h-1.5 rounded-full bg-[var(--color-muted)]">
        <div
          className="absolute top-0 bottom-0 bg-[var(--color-primary)]/25 rounded-full"
          style={{ left: `${bandLeft}%`, right: `${100 - bandRight}%` }}
          aria-hidden="true"
        />
        <div
          className={cn(
            "absolute -top-[4px] w-3.5 h-3.5 rounded-full bg-[var(--color-ink)] ring-2 ring-white dark:ring-[var(--color-card)] transition-all duration-[var(--duration-fast)]",
            markerClassName
          )}
          style={{ left: `calc(${markerPct}% - 7px)` }}
          aria-hidden="true"
        />
      </div>
      {(lowLabel || highLabel) && (
        <div className="mt-1.5 flex justify-between text-[11px] text-[var(--color-ink-variant)] tabular-nums">
          <span>{lowLabel}</span>
          <span>{highLabel}</span>
        </div>
      )}
    </div>
  );
}
