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
import { Card } from '@/components/card';
import { Button } from '@/components/button';
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
    listReceivedShares()
      .then(setShares)
      .catch((e) => {
        setError(e instanceof Error ? e.message : 'Could not load your shared records');
        setShares([]);
      });
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
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-subtext">Loading…</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl font-bold text-text-main mb-1">Shared with me</h1>
        <p className="text-subtext mb-6">
          Records other people shared with you and you chose to keep.
        </p>

        {error && (
          <div className="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-2.5 text-sm text-red-800">
            {error}
          </div>
        )}

        {shares.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="font-medium text-text-main mb-1">Nothing here yet</p>
            <p className="text-subtext text-sm mb-4">
              When someone shares their records with you, open the link and choose
              “Save to my account” to keep it after the link expires.
            </p>
            <Button onClick={() => router.push('/dashboard')}>Back to dashboard</Button>
          </Card>
        ) : (
          <div className="space-y-4">
            {shares.map((share) => {
              const d = detail[share.id];
              return (
                <Card key={share.id} className="p-4 sm:p-6">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <h2 className="font-semibold text-text-main">
                        {share.owner_name}
                      </h2>
                      <p className="text-sm text-subtext">
                        {share.kind === 'all' ? 'Full medical record' : 'Single report'}
                        {' · '}
                        {share.report_count} report{share.report_count === 1 ? '' : 's'}
                        {' · saved '}
                        {formatServerDateTime(share.claimed_at)}
                      </p>
                    </div>
                    <div className="flex gap-2">
                      <Button onClick={() => toggle(share.id)}>
                        {openId === share.id ? 'Hide' : 'View'}
                      </Button>
                      <button
                        onClick={() => remove(share.id)}
                        className="rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                      >
                        Remove
                      </button>
                    </div>
                  </div>

                  {openId === share.id && (
                    <div className="mt-4 border-t border-gray-100 pt-4">
                      {d === 'loading' && <p className="text-subtext text-sm">Loading…</p>}
                      {d && d !== 'loading' && (
                        <>
                          {d.withdrawn_count > 0 && (
                            <p className="mb-3 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
                              {d.withdrawn_count} report
                              {d.withdrawn_count === 1 ? ' was' : 's were'} withdrawn by
                              the sender and can no longer be viewed.
                            </p>
                          )}
                          {d.reports.length === 0 ? (
                            <p className="text-subtext text-sm">
                              Nothing left to show — the sender removed these records.
                            </p>
                          ) : (
                            <ul className="space-y-3">
                              {d.reports.map((r) => (
                                <li
                                  key={r.id}
                                  className="rounded-lg border border-gray-100 p-3"
                                >
                                  <div className="flex flex-wrap items-center justify-between gap-2">
                                    <div>
                                      <p className="font-medium text-text-main">
                                        {r.report_type.replace(/_/g, ' ')}
                                      </p>
                                      <p className="text-xs text-subtext">
                                        {r.file_name}
                                        {r.created_at
                                          ? ` · ${formatServerDateTime(r.created_at)}`
                                          : ''}
                                      </p>
                                    </div>
                                    {r.file_content && (
                                      <button
                                        onClick={() => openReportFile(r)}
                                        className="text-sm font-medium text-primary underline"
                                      >
                                        Open file
                                      </button>
                                    )}
                                  </div>
                                  {r.notes && (
                                    <p className="mt-2 text-sm text-subtext">{r.notes}</p>
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
