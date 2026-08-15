"use client";

import * as React from "react";
import { Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

export type ButtonVariant = "primary" | "secondary" | "ghost" | "destructive";
export type ButtonSize = "md" | "sm";

const variantClasses: Record<ButtonVariant, string> = {
  primary:
    "bg-[var(--color-primary)] text-white hover:bg-[var(--color-primary-hover)] hover:shadow-[var(--shadow-primary-hover)] focus-visible:ring-[var(--color-primary-focus)] shadow-[var(--shadow-primary)] hover:-translate-y-[1px] active:scale-[0.97]",
  secondary:
    "border-2 border-[var(--color-primary)] text-[var(--color-primary)] hover:bg-[var(--color-primary-light)] focus-visible:ring-[var(--color-primary-focus)] hover:-translate-y-[1px]",
  ghost: "text-[var(--color-ink-variant)] hover:bg-[var(--color-muted)] hover:text-[var(--color-ink)] focus-visible:ring-[var(--color-primary-focus)]",
  destructive:
    "bg-[var(--color-alert)] text-white hover:bg-[var(--color-alert-text)] hover:shadow-md focus-visible:ring-[var(--color-alert)] shadow-sm hover:-translate-y-[1px] active:scale-[0.97]",
};

const sizeClasses: Record<ButtonSize, string> = {
  md: "h-12 px-7 text-sm min-h-[var(--touch-standard)] gap-2 rounded-[var(--radius-sm)]",
  sm: "h-10 px-5 text-sm min-h-[var(--touch-min)] gap-1.5 rounded-[var(--radius-sm)]",
};

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  isLoading?: boolean;
  fullWidth?: boolean;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      className,
      variant = "primary",
      size = "md",
      isLoading = false,
      fullWidth = false,
      disabled,
      children,
      ...props
    },
    ref,
  ) => {
    return (
      <button
        ref={ref}
        className={cn(
          "inline-flex items-center justify-center font-semibold transition-all duration-[var(--duration-base)] ease-[var(--ease-standard)] cursor-pointer select-none",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2",
          "disabled:opacity-40 disabled:pointer-events-none",
          variantClasses[variant],
          sizeClasses[size],
          fullWidth && "w-full",
          className,
        )}
        disabled={disabled || isLoading}
        {...props}
      >
        {isLoading && <Loader2 className="w-4 h-4 animate-spin" aria-hidden="true" />}
        {children}
      </button>
    );
  },
);

Button.displayName = "Button";
