import React from 'react';
import { cn } from '@/lib/utils';

export interface BadgeProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: 'default' | 'success' | 'warning' | 'danger' | 'outline';
}

export function Badge({ className, variant = 'default', ...props }: BadgeProps) {
  const variants = {
    default: 'bg-primary/10 text-primary',
    success: 'bg-ok-container text-ok',
    warning: 'bg-caution-container text-caution',
    danger: 'bg-alert-container text-alert',
    outline: 'border border-outline text-on-surface-variant',
  };

  return (
    <div
      className={cn(
        'inline-flex items-center rounded-sm px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring',
        variants[variant],
        className
      )}
      {...props}
    />
  );
}