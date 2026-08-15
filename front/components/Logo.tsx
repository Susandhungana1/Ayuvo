'use client';

import Link from 'next/link';

interface LogoProps {
  /** 'full' = mark + wordmark, 'mark' = icon only, 'wordmark' = text only */
  variant?: 'full' | 'mark' | 'wordmark';
  /** Size scale: 'sm' (28px), 'md' (32px), 'lg' (40px) */
  size?: 'sm' | 'md' | 'lg';
  /** Override href */
  href?: string;
}

const sizes = {
  sm: { box: 28, icon: 16, text: 'text-lg' },
  md: { box: 32, icon: 18, text: 'text-xl' },
  lg: { box: 40, icon: 24, text: 'text-2xl' },
} as const;

export function Logo({ variant = 'full', size = 'md', href = '/' }: LogoProps) {
  const s = sizes[size];

  const mark = (
    <svg
      width={s.box}
      height={s.box}
      viewBox="0 0 40 40"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      {/* Rounded square background — cyan700 */}
      <rect width="40" height="40" rx="10" fill="#0E7490" />
      {/* Medical cross / plus */}
      <path
        d="M20 10.5C20.8284 10.5 21.5 11.1716 21.5 12V18.5H28C28.8284 18.5 29.5 19.1716 29.5 20C29.5 20.8284 28.8284 21.5 28 21.5H21.5V28C21.5 28.8284 20.8284 29.5 20 29.5C19.1716 29.5 18.5 28.8284 18.5 28V21.5H12C11.1716 21.5 10.5 20.8284 10.5 20C10.5 19.1716 11.1716 18.5 12 18.5H18.5V12C18.5 11.1716 19.1716 10.5 20 10.5Z"
        fill="white"
      />
    </svg>
  );

  const wordmark = (
    <span
      className={`font-heading font-semibold text-text-main tracking-tight leading-none ${s.text}`}
    >
      MediStore
    </span>
  );

  if (variant === 'mark') return <Link href={href} className="flex-shrink-0">{mark}</Link>;
  if (variant === 'wordmark') return <Link href={href} className="flex-shrink-0">{wordmark}</Link>;

  return (
    <Link href={href} className="flex-shrink-0 flex items-center gap-2">
      {mark}
      {wordmark}
    </Link>
  );
}