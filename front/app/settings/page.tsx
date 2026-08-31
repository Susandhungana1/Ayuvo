'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { apiFetch, clearSession, API_URL } from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { TwoFactorAuth } from '@/components/two-factor-auth';



export default function Settings() {
  const router = useRouter();
  const { t } = useI18n();
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState('');

  // Change password state
  const [currentPw, setCurrentPw] = useState('');
  const [newPw, setNewPw] = useState('');
  const [confirmPw, setConfirmPw] = useState('');
  const [pwLoading, setPwLoading] = useState(false);
  const [pwMsg, setPwMsg] = useState('');
  const [pwErr, setPwErr] = useState('');

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

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setPwMsg('');
    setPwErr('');
    if (newPw !== confirmPw) {
      setPwErr('Passwords do not match.');
      return;
    }
    if (newPw.length < 8) {
      setPwErr('New password must be at least 8 characters.');
      return;
    }
    setPwLoading(true);
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/auth/change-password`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ current_password: currentPw, new_password: newPw }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.detail || `Request failed (HTTP ${res.status})`);
      }
      setPwMsg('Password updated.');
      setCurrentPw('');
      setNewPw('');
      setConfirmPw('');
    } catch (err) {
      setPwErr(err instanceof Error ? err.message : 'Failed to change password');
    } finally {
      setPwLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-display font-bold text-on-surface mb-8">
          {t('nav.settings')}
        </h1>

        <TwoFactorAuth />

        <div className="h-8" />

        <Card className="p-lg">
          <h2 className="text-lg font-display font-semibold text-on-surface mb-2">
            Change password
          </h2>
          <form onSubmit={handleChangePassword} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-on-surface mb-1">
                Current password
              </label>
              <input
                type="password"
                value={currentPw}
                onChange={(e) => setCurrentPw(e.target.value)}
                required
                className="w-full rounded-sm border border-outline bg-transparent px-3 py-2 text-sm text-on-surface placeholder:text-on-surface-variant"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-on-surface mb-1">
                New password
              </label>
              <input
                type="password"
                value={newPw}
                onChange={(e) => setNewPw(e.target.value)}
                required
                minLength={8}
                className="w-full rounded-sm border border-outline bg-transparent px-3 py-2 text-sm text-on-surface placeholder:text-on-surface-variant"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-on-surface mb-1">
                Confirm new password
              </label>
              <input
                type="password"
                value={confirmPw}
                onChange={(e) => setConfirmPw(e.target.value)}
                required
                minLength={8}
                className="w-full rounded-sm border border-outline bg-transparent px-3 py-2 text-sm text-on-surface placeholder:text-on-surface-variant"
              />
            </div>
            {pwMsg && (
              <p className="text-sm text-[var(--color-ok)]">{pwMsg}</p>
            )}
            {pwErr && (
              <p className="text-sm text-[var(--color-alert)]">{pwErr}</p>
            )}
            <Button type="submit" disabled={pwLoading}>
              {pwLoading ? 'Updating…' : 'Update password'}
            </Button>
          </form>
        </Card>

        <div className="h-8" />

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