'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import dynamic from 'next/dynamic';
import { Card } from '@/components/card';

// Leaflet touches window/document, so load the map client-side only.
const NearbyMap = dynamic(() => import('@/components/NearbyMap'), {
  ssr: false,
  loading: () => <p className="text-subtext text-sm">Loading map…</p>,
});

export default function Nearby() {
  const router = useRouter();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) { router.push('/auth/login'); return; }
    setReady(true);
  }, [router]);

  if (!ready) {
    return <div className="min-h-screen bg-background flex items-center justify-center"><p className="text-subtext">Loading...</p></div>;
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-6">
          <h1 className="text-2xl sm:text-3xl font-bold text-text-main">Nearby Care</h1>
          <p className="text-subtext text-sm mt-1">Hospitals, clinics and pharmacies around you.</p>
        </div>
        <Card className="p-4 sm:p-6">
          <NearbyMap />
        </Card>
      </div>
    </div>
  );
}
