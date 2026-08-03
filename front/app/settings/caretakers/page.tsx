'use client';

/**
 * Patient side: issue a care code, review who holds one, and see what they've
 * changed.
 */

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import {
  AuditEntry,
  CareLink,
  createInvite,
  listAudit,
  listLinks,
  restoreMedicine,
  revokeLink,
} from '@/lib/care';

function Countdown({ expiresAt, onExpired }: { expiresAt: string; onExpired: () => void }) {
  const [left, setLeft] = useState(() => Date.parse(expiresAt) - Date.now());

  useEffect(() => {
    const id = setInterval(() => {
      const remaining = Date.parse(expiresAt) - Date.now();
      setLeft(remaining);
      if (remaining <= 0) onExpired();
    }, 1000);
    return () => clearInterval(id);
  }, [expiresAt, onExpired]);

  if (left <= 0) return <span className="text-red-600">expired</span>;
  const mins = Math.floor(left / 60000);
  const secs = Math.floor((left % 60000) / 1000);
  return (
    <span className="tabular-nums">
      {mins}:{String(secs).padStart(2, '0')}
    </span>
  );
}

const ACTION_LABEL: Record<AuditEntry['action'], string> = {
  create: 'added',
  update: 'updated',
  delete: 'removed',
  restore: 'restored',
};

export default function CaretakersSettings() {
  const router = useRouter();
  const [links, setLinks] = useState<CareLink[]>([]);
  const [audit, setAudit] = useState<AuditEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [unavailable, setUnavailable] = useState(false);
  const [invite, setInvite] = useState<{ code: string; expires_at: string } | null>(null);
  const [issuing, setIssuing] = useState(false);
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    try {
      const [linkRows, auditRows] = await Promise.all([
        listLinks('patient'),
        listAudit().catch(() => [] as AuditEntry[]),
      ]);
      setLinks(linkRows);
      // Only a caretaker's activity is interesting here; the patient's own
      // edits are already visible on the medicines page.
      setAudit(auditRows.filter((e) => e.by_caretaker));
    } catch {
      setUnavailable(true);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!localStorage.getItem('token')) {
      router.push('/auth/login');
      return;
    }
    load();
  }, [router, load]);

  const handleIssue = async () => {
    setIssuing(true);
    setError('');
    setCopied(false);
    try {
      setInvite(await createInvite());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create a code');
    } finally {
      setIssuing(false);
    }
  };

  const handleRevoke = async (link: CareLink) => {
    if (!confirm(`Remove ${link.name} as a caretaker? They'll immediately lose access to your medicines and stop receiving your reminders.`)) {
      return;
    }
    try {
      await revokeLink(link.id);
      setLinks(links.filter((l) => l.id !== link.id));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not remove that caretaker');
    }
  };

  const handleRestore = async (entry: AuditEntry) => {
    if (!entry.medicine_id) return;
    try {
      await restoreMedicine(entry.medicine_id);
      load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not restore that medicine');
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-subtext">Loading…</p>
      </div>
    );
  }

  if (unavailable) {
    return (
      <div className="min-h-screen bg-background">
        <div className="max-w-3xl mx-auto px-4 py-16 text-center">
          <h1 className="text-2xl font-bold text-text-main mb-2">Caretakers</h1>
          <p className="text-subtext">This feature isn&apos;t available on your account yet.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-bold text-text-main mb-2">Caretakers</h1>
        <p className="text-subtext mb-8">
          A caretaker can see and manage your medicines, and gets your medicine
          reminders. They cannot see your vitals, documents, reports or anything else.
        </p>

        {error && (
          <div className="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-2.5 text-sm text-red-800">
            {error}
          </div>
        )}

        {/* --- Issue a code --- */}
        <Card className="p-6 mb-8">
          <h2 className="text-lg font-semibold text-text-main mb-1">Add a caretaker</h2>
          <p className="text-sm text-subtext mb-4">
            Generate a code and read it out to the person with you. It works once,
            and only for the next 15 minutes.
          </p>

          {invite ? (
            <div className="rounded-xl border-2 border-dashed border-primary/40 bg-primary/5 p-6 text-center">
              <p className="font-mono text-3xl sm:text-4xl font-bold tracking-[0.2em] text-text-main mb-3">
                {invite.code}
              </p>
              <div className="flex items-center justify-center gap-3 mb-3">
                <button
                  type="button"
                  onClick={() => {
                    navigator.clipboard?.writeText(invite.code);
                    setCopied(true);
                  }}
                  className="rounded-md border border-primary/40 px-3 py-1.5 text-sm font-medium text-primary hover:bg-primary/10"
                >
                  {copied ? 'Copied' : 'Copy code'}
                </button>
                <span className="text-sm text-subtext">
                  Expires in{' '}
                  <Countdown expiresAt={invite.expires_at} onExpired={() => setInvite(null)} />
                </span>
              </div>
              <p className="text-xs font-medium text-amber-700">
                This code is shown once. Generating a new one cancels this.
              </p>
            </div>
          ) : (
            <Button onClick={handleIssue} disabled={issuing}>
              {issuing ? 'Generating…' : 'Generate a code'}
            </Button>
          )}
        </Card>

        {/* --- Current caretakers --- */}
        <h2 className="text-lg font-semibold text-text-main mb-3">
          Your caretakers {links.length > 0 && `(${links.length})`}
        </h2>
        {links.length === 0 ? (
          <Card className="p-6 mb-8 text-center">
            <p className="text-subtext text-sm">
              Nobody is helping manage your medicines yet.
            </p>
          </Card>
        ) : (
          <div className="space-y-3 mb-8">
            {links.map((link) => (
              <Card key={link.id} className="p-4 flex items-center justify-between gap-4">
                <div>
                  <p className="font-medium text-text-main">{link.name}</p>
                  <p className="text-xs text-subtext">
                    Added {new Date(link.created_at).toLocaleDateString()}
                  </p>
                </div>
                <button
                  onClick={() => handleRevoke(link)}
                  className="text-red-500 text-sm hover:underline shrink-0"
                >
                  Remove
                </button>
              </Card>
            ))}
          </div>
        )}

        {/* --- Caretaker activity --- */}
        <h2 className="text-lg font-semibold text-text-main mb-3">Recent caretaker activity</h2>
        {audit.length === 0 ? (
          <Card className="p-6 text-center">
            <p className="text-subtext text-sm">No changes by a caretaker yet.</p>
          </Card>
        ) : (
          <Card className="divide-y divide-gray-100 p-0">
            {audit.map((entry) => (
              <div key={entry.id} className="flex items-center justify-between gap-4 px-5 py-3">
                <div>
                  <p className="text-sm text-text-main">
                    <span className="font-medium">{entry.actor_name}</span>{' '}
                    {ACTION_LABEL[entry.action]}{' '}
                    <span className="font-medium">{entry.medicine_name || 'a medicine'}</span>
                  </p>
                  <p className="text-xs text-subtext">
                    {new Date(entry.created_at).toLocaleString()}
                  </p>
                </div>
                {entry.action === 'delete' && entry.medicine_id && (
                  <button
                    onClick={() => handleRestore(entry)}
                    className="text-primary text-sm hover:underline shrink-0"
                  >
                    Restore
                  </button>
                )}
              </div>
            ))}
          </Card>
        )}
      </div>
    </div>
  );
}
