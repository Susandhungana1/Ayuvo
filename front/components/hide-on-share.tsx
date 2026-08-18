'use client';

import { usePathname } from 'next/navigation';

export function HideOnShare({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  // Public, no-login pages render without app chrome (navbar/footer).
  if (pathname?.startsWith('/share/')) return null;
  if (pathname?.startsWith('/emergency/id/')) return null;
  return <>{children}</>;
}
