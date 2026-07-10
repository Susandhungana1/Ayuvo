import React from 'react';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline';
  size?: 'sm' | 'md' | 'lg';
  children: React.ReactNode;
}

export function Button({ variant = 'primary', size = 'md', className = '', children, ...props }: ButtonProps) {
  const baseStyles = "inline-flex items-center justify-center rounded-xl font-medium transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed";
  const sizes = { sm: "px-4 py-2 text-sm", md: "px-6 py-2.5", lg: "px-8 py-3 text-lg" };
  
  const variants = {
    primary: "bg-primary text-white hover:bg-blue-700 hover:shadow-md focus:ring-primary",
    secondary: "bg-secondary text-white hover:bg-emerald-600 hover:shadow-md focus:ring-secondary",
    outline: "border-2 border-primary text-primary hover:bg-blue-50 focus:ring-primary"
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
