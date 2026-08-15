import * as React from "react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

export interface EmptyStateProps {
  icon: LucideIcon;
  /** One line saying what this screen is for. */
  title: string;
  description?: string;
  /** The one action that fills this screen. */
  action?: React.ReactNode;
  className?: string;
}

export function EmptyState({ icon: Icon, title, description, action, className }: EmptyStateProps) {
  return (
    <div className={cn("flex flex-col items-center text-center px-lg py-xxxl", className)}>
      <div className="flex items-center justify-center w-12 h-12 rounded-full bg-outline/20 text-on-surface-variant mb-lg">
        <Icon className="w-6 h-6" aria-hidden="true" />
      </div>
      <h3 className="text-lg font-display font-semibold text-on-surface mb-xs">{title}</h3>
      {description && (
        <p className="text-sm text-on-surface-variant max-w-sm mb-lg">{description}</p>
      )}
      {action}
    </div>
  );
}