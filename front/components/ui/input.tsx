"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  hint?: string;
  error?: string;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, label, hint, error, id, ...props }, ref) => {
    const autoId = React.useId();
    const inputId = id || autoId;
    return (
      <div className="flex flex-col gap-2 w-full">
        {label && (
          <label htmlFor={inputId} className="text-sm font-semibold text-[var(--color-ink)]">
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={inputId}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? `${inputId}-error` : hint ? `${inputId}-hint` : undefined}
          className={cn(
            "flex h-12 w-full rounded-[var(--radius-md)] border bg-white dark:bg-[var(--color-card)] px-4 py-3 text-sm text-[var(--color-ink)] placeholder:text-[var(--color-ink-muted)]",
            "shadow-[var(--shadow-xs)] transition-all duration-[var(--duration-base)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-primary-focus)] focus-visible:shadow-[var(--shadow-sm)]",
            error
              ? "border-[var(--color-alert)] focus-visible:border-[var(--color-alert)]"
              : "border-[var(--color-outline-strong)] focus-visible:border-[var(--color-primary)]",
            className,
          )}
          {...props}
        />
        {error ? (
          <p id={`${inputId}-error`} className="text-sm text-[var(--color-alert)] font-medium">
            {error}
          </p>
        ) : hint ? (
          <p id={`${inputId}-hint`} className="text-sm text-[var(--color-ink-variant)]">
            {hint}
          </p>
        ) : null}
      </div>
    );
  },
);

Input.displayName = "Input";
