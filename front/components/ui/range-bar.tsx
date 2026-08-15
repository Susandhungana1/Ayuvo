"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

/**
 * The signature element: a track with the normal band as a filled segment and
 * the reading as a marker on it. Out-of-range is marked by position, not by
 * colour. Used in exactly three places — vitals tiles, lab findings rows, and
 * the shaded normal band behind trend lines — and nowhere else.
 */
export interface RangeBarProps {
  /** Scale extremes (min and max the marker can take, e.g. 60 and 200). */
  min: number;
  max: number;
  /** Normal reference band within the scale (e.g. systolic 90–140). */
  bandStart: number;
  bandEnd: number;
  /** The reading. Clamped to the track. */
  value: number;
  lowLabel?: string;
  highLabel?: string;
  className?: string;
  id?: string;
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
}: RangeBarProps) {
  const markerPct = pct(value, min, max);
  const bandLeft = pct(bandStart, min, max);
  const bandRight = pct(bandEnd, min, max);

  return (
    <div className={cn("w-full", className)} id={id}>
      <div className="relative h-1 rounded-full bg-outline/40">
        {/* normal band — a reference, not a verdict */}
        <div
          className="absolute top-0 bottom-0 bg-primary/25"
          style={{ left: `${bandLeft}%`, right: `${100 - bandRight}%` }}
          aria-hidden="true"
        />
        {/* the reading */}
        <div
          className="absolute -top-[4px] w-3 h-3 rounded-full bg-on-surface ring-2 ring-surface-card transition-left duration-fast"
          style={{ left: `calc(${markerPct}% - 6px)` }}
          aria-hidden="true"
        />
      </div>
      {(lowLabel || highLabel) && (
        <div className="mt-1 flex justify-between text-[11px] text-on-surface-variant tabular-nums">
          <span>{lowLabel}</span>
          <span>{highLabel}</span>
        </div>
      )}
    </div>
  );
}