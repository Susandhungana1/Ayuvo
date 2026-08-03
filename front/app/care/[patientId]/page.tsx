'use client';

/**
 * Caretaker view of one client's medicines.
 *
 * Deliberately medicines-only: no vitals, documents, reports or AI entry
 * points are rendered — and none are fetched either, so the data never reaches
 * this device.
 */

import { useCallback, useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { MedicineManager } from '@/components/medicine-manager';
import { CareLink, listLinks } from '@/lib/care';

export default function CarePage() {
  const router = useRouter();
  const params = useParams<{ patientId: string }>();
  // Next.js has already decoded the route segment, so this is the raw id
  // (with its '#'). Re-encoding happens in scopedUrl at request time.
  const patientId = decodeURIComponent(
    Array.isArray(params.patientId) ? params.patientId[0] : params.patientId || '',
  );

  const [link, setLink] = useState<CareLink | null>(null);
  const [loading, setLoading] = useState(true);
  const [denied, setDenied] = useState(false);

  const leave = useCallback(
    (message: string) => {
      // A toast library isn't part of this app; the dashboard reads the reason
      // from sessionStorage and shows it once.
      sessionStorage.setItem('care:notice', message);
      router.push('/dashboard');
    },
    [router],
  );

  useEffect(() => {
    if (!localStorage.getItem('token')) {
      router.push('/auth/login');
      return;
    }
    listLinks('caretaker')
      .then((links) => {
        const match = links.find((l) => l.user_id === patientId);
        if (!match) {
          setDenied(true);
          return;
        }
        setLink(match);
      })
      .catch(() => setDenied(true))
      .finally(() => setLoading(false));
  }, [patientId, router]);

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-subtext">Loading…</p>
      </div>
    );
  }

  if (denied || !link) {
    return (
      <div className="min-h-screen bg-background">
        <div className="max-w-3xl mx-auto px-4 py-16 text-center">
          <h1 className="text-2xl font-bold text-text-main mb-2">No longer available</h1>
          <p className="text-subtext mb-6">
            You don&apos;t have access to this person&apos;s medicines.
          </p>
          <Link href="/dashboard" className="text-primary hover:underline">
            Back to dashboard
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Amber, not the app's blue: a caretaker must never mistake this page
          for their own medicine list. Sticky directly under the h-16 navbar so
          it survives scrolling — a list of Remove buttons with no attribution
          in view is precisely the confusion this banner exists to prevent. */}
      <div className="bg-amber-100 border-b-2 border-amber-300 sticky top-16 z-40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3 flex items-center justify-between gap-4">
          <p className="text-sm font-medium text-amber-900">
            You&apos;re managing medicines for{' '}
            <span className="font-bold">{link.name}</span>.
          </p>
          <Link
            href="/dashboard"
            className="text-sm font-medium text-amber-900 hover:underline shrink-0"
          >
            Back to my dashboard
          </Link>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-bold text-text-main mb-8">
          {link.name}&apos;s medicines
        </h1>

        <MedicineManager
          patientId={patientId}
          onAccessRevoked={() =>
            leave(`${link.name} removed your caretaker access.`)
          }
        />
      </div>
    </div>
  );
}
