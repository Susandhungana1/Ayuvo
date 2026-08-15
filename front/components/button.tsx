import React from 'react';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  children: React.ReactNode;
}

export function Button({ variant = 'primary', size = 'md', className = '', children, ...props }: ButtonProps) {
  const baseStyles = "inline-flex items-center justify-center font-medium transition-all focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed";
  const sizes = {
    sm: "px-4 py-2 text-sm min-h-[var(--touch-min)]",
    md: "px-6 py-2.5 min-h-[var(--touch-min)]",
    lg: "px-8 py-3 text-lg min-h-[var(--touch-standard)]"
  };
  
  const variants = {
    primary: "bg-[var(--color-primary)] text-white hover:bg-[var(--color-primary-hover)] hover:shadow-md focus:ring-[var(--color-primary-focus)] rounded-[var(--radius-sm)]",
    secondary: "bg-[var(--color-ok)] text-white hover:opacity-90 hover:shadow-md focus:ring-[var(--color-ok)] rounded-[var(--radius-sm)]",
    outline: "border-2 border-[var(--color-primary)] text-[var(--color-primary)] hover:bg-[var(--color-primary-light)] focus:ring-[var(--color-primary-focus)] rounded-[var(--radius-sm)]",
    ghost: "text-[var(--color-ink-variant)] hover:bg-[var(--color-muted)] focus:ring-[var(--color-primary-focus)] rounded-[var(--radius-sm)]"
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