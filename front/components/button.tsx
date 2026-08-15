import React from 'react';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost' | 'destructive';
  size?: 'sm' | 'md' | 'lg';
  children: React.ReactNode;
}

export function Button({ variant = 'primary', size = 'md', className = '', children, ...props }: ButtonProps) {
  const baseStyles = "inline-flex items-center justify-center font-semibold transition-all duration-[var(--duration-base)] ease-[var(--ease-standard)] focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer select-none active:scale-[0.97]";

  const sizes = {
    sm: "px-5 py-2.5 text-sm min-h-[var(--touch-min)] gap-1.5 rounded-[var(--radius-sm)]",
    md: "px-7 py-3 text-sm min-h-[var(--touch-standard)] gap-2 rounded-[var(--radius-sm)]",
    lg: "px-9 py-3.5 text-base min-h-[52px] gap-2.5 rounded-[var(--radius-md)]"
  };

  const variants = {
    primary: "bg-[var(--color-primary)] text-white hover:bg-[var(--color-primary-hover)] hover:shadow-[var(--shadow-primary-hover)] focus:ring-[var(--color-primary-focus)] shadow-[var(--shadow-primary)] hover:-translate-y-[1px]",
    secondary: "bg-[var(--color-ok)] text-white hover:opacity-90 hover:shadow-md focus:ring-[var(--color-ok)] shadow-sm hover:-translate-y-[1px]",
    outline: "border-2 border-[var(--color-primary)] text-[var(--color-primary)] bg-transparent hover:bg-[var(--color-primary-light)] focus:ring-[var(--color-primary-focus)] hover:-translate-y-[1px]",
    ghost: "text-[var(--color-ink-variant)] hover:bg-[var(--color-muted)] hover:text-[var(--color-ink)] focus:ring-[var(--color-primary-focus)]",
    destructive: "bg-[var(--color-alert)] text-white hover:bg-[var(--color-alert-text)] hover:shadow-md focus:ring-[var(--color-alert)] shadow-sm hover:-translate-y-[1px]"
  };

  return (
    <button
      className={`${baseStyles} ${sizes[size]} ${variants[variant]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}
