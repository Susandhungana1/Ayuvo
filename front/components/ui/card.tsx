import * as React from "react";
import { cn } from "@/lib/utils";

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  padding?: "lg" | "none";
  hover?: boolean;
}

export function Card({ className, padding = "lg", hover = false, ...props }: CardProps) {
  return (
    <div
      className={cn(
        "bg-white dark:bg-[var(--color-card)]",
        "shadow-[var(--shadow-sm)] dark:shadow-[var(--shadow-md)]",
        "rounded-[var(--radius-lg)]",
        "border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)]",
        "transition-all duration-[var(--duration-base)] ease-[var(--ease-standard)]",
        padding === "lg" ? "p-7" : "",
        hover && "hover:shadow-[var(--shadow-lg)] hover:border-[var(--color-primary)] hover:-translate-y-0.5 cursor-pointer",
        className,
      )}
      {...props}
    />
  );
}
