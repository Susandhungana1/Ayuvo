import * as React from "react";
import { cn } from "@/lib/utils";

/** Pulsing placeholder shaped like the content it replaces. No shimmer sweep. */
export function Skeleton({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn("animate-pulse rounded-sm bg-outline/40", className)}
      aria-hidden="true"
      {...props}
    />
  );
}