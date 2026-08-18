'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { apiFetch, clearSession } from '@/lib/api';
import { useI18n } from '@/lib/i18n';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

export default function Settings() {
  const router = useRouter();
  const { t } = useI18n();
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
    }
  }, [router]);

  const handleDelete = async () => {
    // Two confirmations, and the second spells out exactly what is lost.
    const first = window.confirm(
      'Delete your account? This erases your profile, every record, every ' +
      'file and every share link. There is no undo.'
    );
    if (!first) return;

    const second = window.confirm(
      'Really delete the account? All your reports, medicines, ' +
      'appointments, vitals, documents and care links will be removed ' +
      'from the server. This cannot be undone.'
    );
    if (!second) return;

    setDeleting(true);
    setError('');
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/users/me`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` },
      });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.detail || `Request failed (HTTP ${res.status})`);
      }
      // The account is gone; drop the local session the way logout does.
      clearSession();
      router.push('/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete the account');
      setDeleting(false);
    }
  };

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-display font-bold text-on-surface mb-8">
          {t('nav.settings')}
        </h1>

        <Card className="p-lg border-l-4 border-l-[var(--color-alert)]">
          <h2 className="text-lg font-display font-semibold text-on-surface mb-2">
            Delete account
          </h2>
          <p className="text-sm text-on-surface-variant mb-4">
            Erases your profile, every record and every file. This cannot be
            undone.
          </p>
          {error && (
            <p className="text-sm text-[var(--color-alert)] mb-4">{error}</p>
          )}
          <Button
            variant="destructive"
            onClick={handleDelete}
            disabled={deleting}
          >
            {deleting ? 'Deleting…' : 'Delete account'}
          </Button>
        </Card>
      </div>
    </div>
  );
}