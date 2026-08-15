import React from 'react';
import { cn } from '@/lib/utils';

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  error?: string;
  label?: string;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type = 'text', error, label, id, ...props }, ref) => {
    const inputId = id || React.useId();

    return (
      <div className="flex flex-col gap-2 w-full">
        {label && (
          <label htmlFor={inputId} className="text-sm font-semibold text-[var(--color-ink)] tracking-tight">
            {label}
          </label>
        )}
        <input
          id={inputId}
          type={type}
          className={cn(
            'flex h-12 w-full rounded-[var(--radius-md)] border border-[var(--color-outline)] bg-white dark:bg-[var(--color-card)] px-4 py-3 text-sm placeholder:text-[var(--color-ink-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-primary-focus)] focus-visible:border-[var(--color-primary)] focus-visible:shadow-[var(--shadow-sm)] disabled:cursor-not-allowed disabled:opacity-50 transition-all duration-[var(--duration-base)] shadow-[var(--shadow-xs)]',
            error && 'border-[var(--color-alert)] focus-visible:ring-[var(--color-alert)] focus-visible:border-[var(--color-alert)]',
            className
          )}
          ref={ref}
          {...props}
        />
        {error && <span className="text-xs text-[var(--color-alert)] font-medium mt-0.5">{error}</span>}
      </div>
    );
  }
);

Input.displayName = 'Input';
