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
      <div className="flex flex-col gap-sm w-full">
        {label && (
          <label htmlFor={inputId} className="text-sm font-semibold text-on-surface">
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={inputId}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? `${inputId}-error` : hint ? `${inputId}-hint` : undefined}
          className={cn(
            "flex h-11 w-full rounded-sm border bg-surface-card px-3.5 text-base text-on-surface placeholder:text-on-surface-variant/70",
            "transition-colors duration-fast focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring",
            error
              ? "border-error focus-visible:border-error"
              : "border-outline focus-visible:border-transparent",
            className,
          )}
          {...props}
        />
        {error ? (
          <p id={`${inputId}-error`} className="text-sm text-error">
            {error}
          </p>
        ) : hint ? (
          <p id={`${inputId}-hint`} className="text-sm text-on-surface-variant">
            {hint}
          </p>
        ) : null}
      </div>
    );
  },
);

Input.displayName = "Input";