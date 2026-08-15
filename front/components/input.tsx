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
      <div className="flex flex-col gap-1.5 w-full">
        {label && (
          <label htmlFor={inputId} className="text-sm font-medium text-[var(--color-ink)]">
            {label}
          </label>
        )}
        <input
          id={inputId}
          type={type}
          className={cn(
            'flex h-10 w-full rounded-[var(--radius-sm)] border border-[var(--color-outline)] bg-white dark:bg-[var(--color-card)] px-3 py-2 text-sm placeholder:text-[var(--color-ink-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-primary-focus)] focus-visible:border-transparent disabled:cursor-not-allowed disabled:opacity-50 transition-colors',
            error && 'border-[var(--color-alert)] focus-visible:ring-[var(--color-alert)]',
            className
          )}
          ref={ref}
          {...props}
        />
        {error && <span className="text-xs text-[var(--color-alert)] font-medium">{error}</span>}
      </div>
    );
  }
);

Input.displayName = 'Input';