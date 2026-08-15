import * as React from "react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

export interface EmptyStateProps {
  icon: LucideIcon;
  title: string;
  description?: string;
  action?: React.ReactNode;
  className?: string;
}

export function EmptyState({ icon: Icon, title, description, action, className }: EmptyStateProps) {
  return (
    <div className={cn("flex flex-col items-center text-center px-7 py-16", className)}>
      <div className="flex items-center justify-center w-14 h-14 rounded-full bg-[var(--color-muted)] text-[var(--color-ink-variant)] mb-5">
        <Icon className="w-7 h-7" aria-hidden="true" />
      </div>
      <h3 className="text-lg font-semibold text-[var(--color-ink)] mb-1.5">{title}</h3>
      {description && (
        <p className="text-sm text-[var(--color-ink-variant)] max-w-sm mb-5">{description}</p>
      )}
      {action}
    </div>
  );
}
