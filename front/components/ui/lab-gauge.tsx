"use client";

import * as React from "react";
import { cn } from "@/lib/utils";
import { RangeBar } from "@/components/ui/range-bar";

export interface LabGaugeProps {
  value: number;
  unit: string;
  /** A reference range label like "12–17.5", "< 200", "> 40" or "-". */
  referenceRange: string;
  status: "HIGH" | "LOW" | "NORMAL";
  className?: string;
}

/** Parse a range label into its numeric bounds (en-dash, hyphen or one-sided). */
export function parseRange(label: string): { low?: number; high?: number } {
  const enDash = label.includes("–") ? "–" : "-";
  const both = label.split(enDash);
  if (both.length === 2) {
    const low = parseFloat(both[0]);
    const high = parseFloat(both[1]);
    if (!Number.isNaN(low) && !Number.isNaN(high)) return { low, high };
  }
  const m = label.match(/[<>]\s*([\d.]+)/);
  if (m) {
    const v = parseFloat(m[1]);
    if (!Number.isNaN(v)) {
      return label.trimStart().startsWith("<") ? { high: v } : { low: v };
    }
  }
  return {};
}

/** A window that always contains both the value and the normal band. */
function windowFor(
  value: number,
  low?: number,
  high?: number
): { min: number; max: number } {
  const pad = (v: number) => Math.max(1, Math.abs(v) * 0.15);
  if (low !== undefined && high !== undefined) {
    let min = low - pad(high - low);
    let max = high + pad(high - low);
    if (value < min) min = value - pad(value);
    if (value > max) max = value + pad(value);
    return { min, max };
  }
  if (high !== undefined) {
    return { min: 0, max: Math.max(high, value) * 1.25 };
  }
  if (low !== undefined) {
    return {
      min: Math.min(low, value) * 0.75,
      max: Math.max(low, value) * 1.15,
    };
  }
  const centre = value || 1;
  return { min: centre * 0.8, max: centre * 1.2 };
}

const MARKER_COLORS: Record<LabGaugeProps["status"], string> = {
  HIGH: "bg-[var(--color-alert)]",
  LOW: "bg-[var(--color-caution)]",
  NORMAL: "bg-[var(--color-ok)]",
};

/** A mini range gauge: the normal band on a track, the value as a marker. */
export function LabGauge({
  value,
  unit,
  referenceRange,
  status,
  className,
}: LabGaugeProps) {
  const range = parseRange(referenceRange);
  const window = windowFor(value, range.low, range.high);
  const lowLabel =
    range.low !== undefined
      ? `${range.low} ${unit}`
      : `${Math.round(window.min)} ${unit}`;
  const highLabel =
    range.high !== undefined
      ? `${range.high} ${unit}`
      : `${Math.round(window.max)} ${unit}`;

  return (
    <div className={cn("w-full", className)}>
      <RangeBar
        min={window.min}
        max={window.max}
        bandStart={range.low ?? window.min}
        bandEnd={range.high ?? window.max}
        value={value}
        lowLabel={lowLabel}
        highLabel={highLabel}
        markerClassName={MARKER_COLORS[status]}
      />
    </div>
  );
}
