"use client";

import * as React from "react";
import { ArrowDown, ArrowUp } from "lucide-react";
import { cn } from "@/lib/utils";

export type StatusLevel = "ok" | "caution" | "alert";

const levelClasses: Record<StatusLevel, string> = {
  ok: "bg-[var(--color-ok-container)] text-[var(--color-ok)]",
  caution: "bg-[var(--color-caution-container)] text-[var(--color-caution)]",
  alert: "bg-[var(--color-alert-container)] text-[var(--color-alert)]",
};

export interface StatusChipProps extends React.HTMLAttributes<HTMLSpanElement> {
  level: StatusLevel;
  label: string;
  trend?: "up" | "down";
}

export function StatusChip({ level, label, trend, className, ...props }: StatusChipProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-3 py-1 text-xs font-semibold",
        levelClasses[level],
        className,
      )}
      {...props}
    >
      {trend === "up" && <ArrowUp className="w-3.5 h-3.5" aria-hidden="true" />}
      {trend === "down" && <ArrowDown className="w-3.5 h-3.5" aria-hidden="true" />}
      {label}
    </span>
  );
}
