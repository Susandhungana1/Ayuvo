"use client";

import * as React from "react";
import { ArrowDown, ArrowUp } from "lucide-react";
import { cn } from "@/lib/utils";

export type StatusLevel = "ok" | "caution" | "alert";

const levelClasses: Record<StatusLevel, string> = {
  ok: "bg-ok-container text-ok",
  caution: "bg-caution-container text-caution",
  alert: "bg-alert-container text-alert",
};

export interface StatusChipProps extends React.HTMLAttributes<HTMLSpanElement> {
  level: StatusLevel;
  label: string;
  /** Direction of the band the value moved into — never shown without the label. */
  trend?: "up" | "down";
}

export function StatusChip({ level, label, trend, className, ...props }: StatusChipProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-semibold",
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