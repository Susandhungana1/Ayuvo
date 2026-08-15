import React from 'react';

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  hover?: boolean;
  children: React.ReactNode;
}

export function Card({ hover = false, children, className = '', ...props }: CardProps) {
  return (
    <div
      className={`
        bg-white dark:bg-[var(--color-card)]
        shadow-[var(--shadow-sm)] dark:shadow-[var(--shadow-md)]
        rounded-[var(--radius-lg)]
        p-7
        border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)]
        transition-all duration-[var(--duration-base)] ease-[var(--ease-standard)]
        ${hover ? 'hover:shadow-[var(--shadow-lg)] hover:border-[var(--color-primary)] hover:-translate-y-0.5 cursor-pointer' : ''}
        ${className}
      `}
      {...props}
    >
      {children}
    </div>
  );
}
