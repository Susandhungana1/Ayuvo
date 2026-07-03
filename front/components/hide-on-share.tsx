'use client';

import { usePathname } from 'next/navigation';

export function HideOnShare({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  if (pathname?.startsWith('/share/')) return null;
  return <>{children}</>;
}
