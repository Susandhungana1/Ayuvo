'use client';

/**
 * "Shared with me" — records other people shared and this user chose to keep.
 *
 * What is listed here is a frozen reference, not a copy: the set of reports was
 * fixed when the share was saved (later uploads by the sender never appear),
 * and each one is resolved live, so anything the sender has since deleted drops
 * out and is reported as withdrawn rather than silently vanishing.
 */

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Inbox, FolderOpen } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { EmptyState } from '@/components/ui/empty-state';
import { formatServerDateTime } from '@/lib/datetime';
import {
  ReceivedShare,
  ReceivedShareDetail,
  SharedReport,
  dropReceivedShare,
  listReceivedShares,
  readReceivedShare,
} from '@/lib/shares';

function openReportFile(report: SharedReport) {
  if (!report.file_content) return;
  const chars = atob(report.file_content);
  const bytes = new Uint8Array(chars.length);
  for (let i = 0; i < chars.length; i++) bytes[i] = chars.charCodeAt(i);
  const mime = report.file_name?.toLowerCase().endsWith('.pdf')
    ? 'application/pdf'
    : 'image/png';
  const url = URL.createObjectURL(new Blob([bytes], { type: mime }));
  window.open(url, '_blank', 'noopener');
}

export default function SharedWithMePage() {
  const router = useRouter();
  const [shares, setShares] = useState<ReceivedShare[] | null>(null);
  const [error, setError] = useState('');
  const [openId, setOpenId] = useState<string | null>(null);
  const [detail, setDetail] = useState<Record<string, ReceivedShareDetail | 'loading'>>({});

  useEffect(() => {
    if (!localStorage.getItem('token')) {
      router.push('/auth/login?next=/shared-with-me');
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const rows = await listReceivedShares();
        if (!cancelled) setShares(rows);
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : 'Could not load your shared records');
          setShares([]);
        }
      }
    })();
    return () => { cancelled = true; };
  }, [router]);

  const toggle = async (id: string) => {
    if (openId === id) {
      setOpenId(null);
      return;
    }
    setOpenId(id);
    if (detail[id]) return;
    setDetail((d) => ({ ...d, [id]: 'loading' }));
    try {
      const loaded = await readReceivedShare(id);
      setDetail((d) => ({ ...d, [id]: loaded }));
    } catch {
      setDetail((d) => {
        const next = { ...d };
        delete next[id];
        return next;
      });
      setError('Could not open that share. The sender may have withdrawn it.');
    }
  };

  const remove = async (id: string) => {
    if (!confirm('Remove this from your shared records? You can only get it back if the sender shares again.')) return;
    try {
      await dropReceivedShare(id);
      setShares((s) => (s || []).filter((x) => x.id !== id));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not remove that share');
    }
  };

  if (shares === null) {
    return (
      <div className="min-h-screen bg-surface flex items-center justify-center">
        <p className="text-on-surface-variant">Loading…</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl font-display font-bold text-on-surface mb-xs">Shared with me</h1>
        <p className="text-on-surface-variant mb-xl">
          Records other people shared with you and you chose to keep.
        </p>

        {error && (
          <div className="mb-xl rounded-md border border-alert/40 bg-alert-container px-4 py-2.5 text-sm text-alert">
            {error}
          </div>
        )}

        {shares.length === 0 ? (
          <Card>
            <EmptyState
              icon={Inbox}
              title="Nothing here yet"
              description="When someone shares their records with you, open the link and choose “Save to my account” to keep it after the link expires."
              action={<Button onClick={() => router.push('/dashboard')}>Back to dashboard</Button>}
            />
          </Card>
        ) : (
          <div className="space-y-lg">
            {shares.map((share) => {
              const d = detail[share.id];
              return (
                <Card key={share.id}>
                  <div className="flex flex-wrap items-start justify-between gap-sm">
                    <div>
                      <h2 className="font-semibold text-on-surface">
                        {share.owner_name}
                      </h2>
                      <p className="text-sm text-on-surface-variant">
                        {share.kind === 'all' ? 'Full medical record' : 'Single report'}
                        {' · '}
                        {share.report_count} report{share.report_count === 1 ? '' : 's'}
                        {' · saved '}
                        {formatServerDateTime(share.claimed_at)}
                      </p>
                    </div>
                    <div className="flex gap-sm">
                      <Button size="sm" onClick={() => toggle(share.id)}>
                        {openId === share.id ? 'Hide' : 'View'}
                      </Button>
                      <Button size="sm" variant="ghost" onClick={() => remove(share.id)}>
                        Remove
                      </Button>
                    </div>
                  </div>

                  {openId === share.id && (
                    <div className="mt-lg border-t border-outline/60 pt-lg">
                      {d === 'loading' && <p className="text-on-surface-variant text-sm">Loading…</p>}
                      {d && d !== 'loading' && (
                        <>
                          {d.withdrawn_count > 0 && (
                            <p className="mb-md rounded-md border border-caution/40 bg-caution-container px-3 py-2 text-sm text-caution">
                              {d.withdrawn_count} report
                              {d.withdrawn_count === 1 ? ' was' : 's were'} withdrawn by
                              the sender and can no longer be viewed.
                            </p>
                          )}
                          {d.reports.length === 0 ? (
                            <p className="text-on-surface-variant text-sm">
                              Nothing left to show — the sender removed these records.
                            </p>
                          ) : (
                            <ul className="space-y-md">
                              {d.reports.map((r) => (
                                <li
                                  key={r.id}
                                  className="rounded-md border border-outline/60 p-md"
                                >
                                  <div className="flex flex-wrap items-center justify-between gap-sm">
                                    <div className="flex items-start gap-sm min-w-0">
                                      <FolderOpen className="w-4 h-4 mt-0.5 text-on-surface-variant shrink-0" aria-hidden="true" />
                                      <div className="min-w-0">
                                        <p className="font-medium text-on-surface">
                                          {r.report_type.replace(/_/g, ' ')}
                                        </p>
                                        <p className="text-xs text-on-surface-variant">
                                          {r.file_name}
                                          {r.created_at
                                            ? ` · ${formatServerDateTime(r.created_at)}`
                                            : ''}
                                        </p>
                                      </div>
                                    </div>
                                    {r.file_content && (
                                      <button
                                        onClick={() => openReportFile(r)}
                                        className="text-sm font-semibold text-primary hover:underline shrink-0"
                                      >
                                        Open file
                                      </button>
                                    )}
                                  </div>
                                  {r.notes && (
                                    <p className="mt-sm text-sm text-on-surface-variant">{r.notes}</p>
                                  )}
                                </li>
                              ))}
                            </ul>
                          )}
                        </>
                      )}
                    </div>
                  )}
                </Card>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}