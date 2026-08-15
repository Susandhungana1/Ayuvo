'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import dynamic from 'next/dynamic';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';

// Leaflet touches window/document, so load the map client-side only.
const NearbyMap = dynamic(() => import('@/components/NearbyMap'), {
  ssr: false,
  loading: () => <Skeleton className="w-full" style={{ height: 480 }} />,
});

export default function Nearby() {
  const router = useRouter();
  const [ready] = useState(() => {
    if (typeof window === 'undefined') return false;
    return !!localStorage.getItem('token');
  });

  useEffect(() => {
    if (!ready) {
      router.push('/auth/login');
    }
  }, [ready, router]);

  if (!ready) {
    return <div className="min-h-screen bg-surface flex items-center justify-center"><p className="text-on-surface-variant">Loading...</p></div>;
  }

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-xl">
          <h1 className="text-2xl sm:text-3xl font-display font-bold text-on-surface">Nearby Care</h1>
          <p className="text-on-surface-variant text-sm mt-xs">Hospitals, clinics and pharmacies around you.</p>
        </div>
        <Card>
          <NearbyMap />
        </Card>
      </div>
    </div>
  );
}