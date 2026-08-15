'use client';

/**
 * Patient side: issue a care code, review who holds one, and see what they've
 * changed.
 */

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import {
  AuditEntry,
  CareFeatureOff,
  CareLink,
  SessionExpired,
  createInvite,
  listAudit,
  listLinks,
  restoreMedicine,
  revokeLink,
} from '@/lib/care';

/** Path to sign in at, returning here once that's done. */
const LOGIN_URL = `/auth/login?next=${encodeURIComponent('/settings/caretakers')}`;

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

  if (left <= 0) return <span className="text-alert">expired</span>;
  const mins = Math.floor(left / 60000);
  const secs = Math.floor((left % 60000) / 1000);
  return (
    <span className="tabular-nums">
      {mins}:{String(secs).padStart(2, '0')}
    </span>
  );
}

/**
 * A generated code has to survive leaving the page: it stays valid on the
 * server for 15 minutes, so the UI offering "Generate a code" again — and
 * invalidating the one the user is still reading aloud — is simply wrong.
 *
 * It can only be remembered here. The server keeps just the SHA-256 hash, by
 * design, so there is nothing to fetch it back from.
 *
 * sessionStorage rather than localStorage: this is a short-lived secret, and
 * per-tab storage that dies with the tab is the right lifetime. It is no more
 * exposed than the auth token already in localStorage, and it expires in
 * minutes.
 */
const INVITE_KEY = 'care:invite';

interface StoredInvite {
  code: string;
  expires_at: string;
  /** Caretaker count when issued, to detect that the code has been redeemed. */
  linkCount: number;
}

function readStoredInvite(): StoredInvite | null {
  try {
    const raw = sessionStorage.getItem(INVITE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as StoredInvite;
    if (Date.parse(parsed.expires_at) <= Date.now()) {
      sessionStorage.removeItem(INVITE_KEY);
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

function writeStoredInvite(value: StoredInvite | null) {
  try {
    if (value) sessionStorage.setItem(INVITE_KEY, JSON.stringify(value));
    else sessionStorage.removeItem(INVITE_KEY);
  } catch {
    /* private mode / storage disabled — the code still shows for this view */
  }
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
  const [redirecting, setRedirecting] = useState(false);
  const [blocked, setBlocked] = useState<null | { title: string; detail: string }>(null);
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
      setBlocked(null);

      // Restore a code issued before the user navigated away. If a caretaker
      // has appeared since it was issued, it has been redeemed — showing it
      // would invite the patient to read out a code that no longer works.
      const stored = readStoredInvite();
      if (stored) {
        if (linkRows.length > stored.linkCount) {
          writeStoredInvite(null);
          setInvite(null);
        } else {
          setInvite({ code: stored.code, expires_at: stored.expires_at });
        }
      }
    } catch (err) {
      // Name the actual cause. Reporting every failure as "not available on
      // your account" is misleading when the server is simply unreachable, and
      // gives no hint of what to do about it.
      if (err instanceof SessionExpired) {
        // The token in this browser is dead — held here, the page can only
        // offer a "Try again" that fails identically every time. care.ts has
        // already cleared it, so signing in is both the fix and the only
        // thing to do; go straight there.
        //
        // Stay on the spinner until the route changes. `finally` drops
        // `loading` either way, and without this the empty caretaker list
        // flashes up for a frame on its way out.
        setRedirecting(true);
        router.replace(LOGIN_URL);
      } else if (err instanceof CareFeatureOff) {
        setBlocked({
          title: 'Caretakers is switched off',
          detail:
            'This server has the caretaker feature disabled. It needs CARETAKER_ENABLED=true to be set on the API.',
        });
      } else {
        setBlocked({
          title: "Couldn't load caretakers",
          detail:
            err instanceof Error
              ? `${err.message.replace(/\.?$/, '.')} Check that the API is reachable, then reload.`
              : 'The API could not be reached. Check your connection and reload.',
        });
      }
    } finally {
      setLoading(false);
    }
  }, [router]);

  useEffect(() => {
    if (!localStorage.getItem('token')) {
      router.replace(LOGIN_URL);
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const [linkRows, auditRows] = await Promise.all([
          listLinks('patient'),
          listAudit().catch(() => [] as AuditEntry[]),
        ]);
        if (cancelled) return;
        setLinks(linkRows);
        // Only a caretaker's activity is interesting here; the patient's own
        // edits are already visible on the medicines page.
        setAudit(auditRows.filter((e) => e.by_caretaker));
        setBlocked(null);

        // Restore a code issued before the user navigated away. If a caretaker
        // has appeared since it was issued, it has been redeemed — showing it
        // would invite the patient to read out a code that no longer works.
        const stored = readStoredInvite();
        if (stored) {
          if (linkRows.length > stored.linkCount) {
            writeStoredInvite(null);
            setInvite(null);
          } else {
            setInvite({ code: stored.code, expires_at: stored.expires_at });
          }
        }
      } catch (err) {
        // Name the actual cause. Reporting every failure as "not available on
        // your account" is misleading when the server is simply unreachable, and
        // gives no hint of what to do about it.
        if (cancelled) return;
        if (err instanceof SessionExpired) {
          // The token in this browser is dead — held here, the page can only
          // offer a "Try again" that fails identically every time. care.ts has
          // already cleared it, so signing in is both the fix and the only
          // thing to do; go straight there.
          //
          // Stay on the spinner until the route changes. `finally` drops
          // `loading` either way, and without this the empty caretaker list
          // flashes up for a frame on its way out.
          setRedirecting(true);
          router.replace(LOGIN_URL);
        } else if (err instanceof CareFeatureOff) {
          setBlocked({
            title: 'Caretakers is switched off',
            detail:
              'This server has the caretaker feature disabled. It needs CARETAKER_ENABLED=true to be set on the API.',
          });
        } else {
          setBlocked({
            title: "Couldn't load caretakers",
            detail:
              err instanceof Error
                ? `${err.message.replace(/\.?$/, '.')} Check that the API is reachable, then reload.`
                : 'The API could not be reached. Check your connection and reload.',
          });
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [router]);

  const handleIssue = async () => {
    setIssuing(true);
    setError('');
    setCopied(false);
    try {
      const created = await createInvite();
      setInvite(created);
      writeStoredInvite({ ...created, linkCount: links.length });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create a code');
    } finally {
      setIssuing(false);
    }
  };

  const forgetInvite = () => {
    writeStoredInvite(null);
    setInvite(null);
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

  if (loading || redirecting) {
    return (
      <div className="min-h-screen bg-surface flex items-center justify-center">
        <p className="text-on-surface-variant">
          {redirecting ? 'Session expired — taking you to sign in…' : 'Loading…'}
        </p>
      </div>
    );
  }

  if (blocked) {
    return (
      <div className="min-h-screen bg-surface">
        <div className="max-w-3xl mx-auto px-4 py-16 text-center">
          <h1 className="text-2xl font-display font-bold text-on-surface mb-sm">{blocked.title}</h1>
          <p className="text-on-surface-variant mb-xl">{blocked.detail}</p>
          <button
            onClick={() => {
              setLoading(true);
              load();
            }}
            className="text-primary hover:underline text-sm font-medium"
          >
            Try again
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-display font-bold text-on-surface mb-sm">Caretakers</h1>
        <p className="text-on-surface-variant mb-lg">
          A caretaker can see and manage your medicines, and gets your medicine
          reminders. They cannot see your vitals, documents, reports or anything else.
        </p>

        {error && (
          <div className="mb-xl rounded-md border border-alert/40 bg-alert-container px-4 py-2.5 text-sm text-alert">
            {error}
          </div>
        )}

        {/* --- Issue a code --- */}
        <Card className="p-xl mb-lg">
          <h2 className="text-lg font-display font-semibold text-on-surface mb-xs">Add a caretaker</h2>
          <p className="text-sm text-on-surface-variant mb-lg">
            Generate a code and read it out to the person with you. It works once,
            and only for the next 15 minutes.
          </p>

          {invite ? (
            <div className="rounded-lg border-2 border-dashed border-primary/40 bg-primary/5 p-xl text-center">
              <p className="font-mono text-3xl sm:text-4xl font-bold tracking-[0.2em] text-on-surface mb-md">
                {invite.code}
              </p>
              <div className="flex items-center justify-center gap-md mb-md">
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
                <span className="text-sm text-on-surface-variant">
                  Expires in <Countdown expiresAt={invite.expires_at} onExpired={forgetInvite} />
                </span>
                <button
                  type="button"
                  onClick={forgetInvite}
                  className="text-sm text-on-surface-variant hover:text-on-surface underline"
                >
                  Hide
                </button>
              </div>
              <p className="text-xs font-medium text-caution">
                This code can&apos;t be shown again once hidden or expired.
                Generating a new one cancels it.
              </p>
            </div>
          ) : (
            <Button onClick={handleIssue} disabled={issuing}>
              {issuing ? 'Generating…' : 'Generate a code'}
            </Button>
          )}
        </Card>

        {/* --- Current caretakers --- */}
        <h2 className="text-lg font-display font-semibold text-on-surface mb-md">
          Your caretakers {links.length > 0 && `(${links.length})`}
        </h2>
        {links.length === 0 ? (
          <Card className="p-xl mb-lg text-center">
            <p className="text-on-surface-variant text-sm">
              Nobody is helping manage your medicines yet.
            </p>
          </Card>
        ) : (
          <div className="space-y-md mb-lg">
            {links.map((link) => (
              <Card key={link.id} className="p-lg flex items-center justify-between gap-lg">
                <div>
                  <p className="font-medium text-on-surface">{link.name}</p>
                  <p className="text-xs text-on-surface-variant">
                    Added {new Date(link.created_at).toLocaleDateString()}
                  </p>
                </div>
                <button
                  onClick={() => handleRevoke(link)}
                  className="text-alert text-sm hover:underline shrink-0"
                >
                  Remove
                </button>
              </Card>
            ))}
          </div>
        )}

        {/* --- Caretaker activity --- */}
        <h2 className="text-lg font-display font-semibold text-on-surface mb-md">Recent caretaker activity</h2>
        {audit.length === 0 ? (
          <Card className="p-xl text-center">
            <p className="text-on-surface-variant text-sm">No changes by a caretaker yet.</p>
          </Card>
        ) : (
          <Card className="divide-y divide-outline/40 p-0">
            {audit.map((entry) => (
              <div key={entry.id} className="flex items-center justify-between gap-lg px-lg py-md">
                <div>
                  <p className="text-sm text-on-surface">
                    <span className="font-medium">{entry.actor_name}</span>{' '}
                    {ACTION_LABEL[entry.action]}{' '}
                    <span className="font-medium">{entry.medicine_name || 'a medicine'}</span>
                  </p>
                  <p className="text-xs text-on-surface-variant">
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
