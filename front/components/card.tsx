import React from 'react';

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
}

export function Card({ children, className = '', ...props }: CardProps) {
  return (
    <div 
      className={`bg-white shadow-sm rounded-xl p-6 border border-gray-100 ${className}`}
      {...props}
    >
      {children}
    </div>
  );
}
