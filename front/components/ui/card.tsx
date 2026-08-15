import * as React from "react";
import { cn } from "@/lib/utils";

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  /** "lg" (default) — screen/card padding. "none" — flush content (lists, images). */
  padding?: "lg" | "none";
}

export function Card({ className, padding = "lg", ...props }: CardProps) {
  return (
    <div
      className={cn(
        "bg-surface-card border border-outline rounded-md",
        padding === "lg" ? "p-lg" : "",
        className,
      )}
      {...props}
    />
  );
}