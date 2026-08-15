import React from 'react';

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
}

export function Card({ children, className = '', ...props }: CardProps) {
  return (
    <div 
      className={`bg-white dark:bg-[var(--color-card)] shadow-sm rounded-[var(--radius-md)] p-6 border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] ${className}`}
      {...props}
    >
      {children}
    </div>
  );
}