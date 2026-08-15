'use client';

/**
 * Dashboard section listing the people this user cares for.
 *
 * Renders nothing at all unless there is at least one active link, so the
 * dashboard is unchanged for everyone who isn't a caretaker.
 */

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { Bell, BellOff, Users } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { EmptyState } from '@/components/ui/empty-state';
import { CareLink, listLinks, redeemInvite, setNotify } from '@/lib/care';

/**
 * The dose time is the patient's own clock and is rendered verbatim. Passing
 * it through `Date` would re-express it in the caretaker's timezone and show a
 * time that neither party acts on.
 */
function nextDoseLabel(link: CareLink): string {
  if (!link.next_dose_local || !link.next_dose_name) return 'No upcoming doses';
  const when = link.next_dose_is_today
    ? link.next_dose_local
    : `${link.next_dose_local} tomorrow`;

  // Say whose clock it is, but only when the two differ — otherwise it's noise.
  let here: string | undefined;
  try {
    here = Intl.DateTimeFormat().resolvedOptions().timeZone;
  } catch {
    here = undefined;
  }
  const elsewhere =
    link.next_dose_timezone && here && link.next_dose_timezone !== here;

  return `${link.next_dose_name} at ${when}${elsewhere ? ' (their time)' : ''}`;
}

export function PeopleICareFor() {
  const [links, setLinks] = useState<CareLink[]>([]);
  const [ready, setReady] = useState(false);
  const [adding, setAdding] = useState(false);
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const fetchLinks = useCallback(async (): Promise<CareLink[]> => {
    try {
      return await listLinks('caretaker');
    } catch {
      // Feature off, or offline — either way show nothing.
      return [];
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const list = await fetchLinks();
      if (!cancelled) {
        setLinks(list);
        setReady(true);
      }
    })();
    return () => { cancelled = true; };
  }, [fetchLinks]);

  const handleRedeem = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      await redeemInvite(code);
      setCode('');
      setAdding(false);
      setLinks(await fetchLinks());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not use that code');
    } finally {
      setBusy(false);
    }
  };

  const toggleMute = async (link: CareLink) => {
    // Optimistic: the toggle should feel instant, and a failure just reloads.
    setLinks(links.map((l) => (l.id === link.id ? { ...l, notify: !l.notify } : l)));
    try {
      await setNotify(link.id, !link.notify);
    } catch {
      setLinks(await fetchLinks());
    }
  };

  if (!ready) return null;
  // Nothing to show and nothing being added: stay completely out of the way.
  if (links.length === 0 && !adding) {
    return (
      <div className="mt-10">
        <button
          onClick={() => setAdding(true)}
          className="text-sm text-on-surface-variant hover:text-primary transition-colors"
        >
          + Caring for someone? Enter their code
        </button>
      </div>
    );
  }

  return (
    <section className="mt-12">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-display font-bold text-on-surface">People I care for</h2>
        {!adding && (
          <button
            onClick={() => setAdding(true)}
            className="text-sm font-medium text-primary hover:underline"
          >
            + Add someone
          </button>
        )}
      </div>

      {adding && (
        <Card className="p-lg mb-4">
          <form onSubmit={handleRedeem} className="flex flex-wrap items-end gap-3">
            <div className="flex flex-col gap-1.5 grow min-w-[200px]">
              <label htmlFor="care-code" className="text-sm font-semibold text-on-surface">
                Their care code
              </label>
              <input
                id="care-code"
                value={code}
                onChange={(e) => setCode(e.target.value.toUpperCase())}
                placeholder="XXXX-XXXX"
                autoComplete="off"
                className="flex h-11 rounded-sm border border-outline bg-surface-card px-3.5 font-mono tracking-widest text-base text-on-surface placeholder:text-on-surface-variant/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring"
              />
            </div>
            <Button type="submit" disabled={busy || !code.trim()}>
              {busy ? 'Checking…' : 'Add'}
            </Button>
            <Button
              type="button"
              variant="ghost"
              onClick={() => {
                setAdding(false);
                setError('');
              }}
            >
              Cancel
            </Button>
          </form>
          {error && <p className="mt-3 text-sm text-alert">{error}</p>}
        </Card>
      )}

      {links.length === 0 ? (
        <Card className="p-lg">
          <EmptyState
            icon={Users}
            title="No one linked yet"
            description="A patient shares a care code with you from their settings; enter it above to manage their medicines and reminders."
          />
        </Card>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {links.map((link) => (
            <Card key={link.id} className="p-lg">
              <div className="flex items-start justify-between gap-2 mb-3">
                <div>
                  <h3 className="font-display font-semibold text-on-surface">{link.name}</h3>
                  <p className="text-xs text-on-surface-variant">
                    {link.medicine_count ?? 0} medicine
                    {link.medicine_count === 1 ? '' : 's'}
                  </p>
                </div>
                <button
                  onClick={() => toggleMute(link)}
                  title={link.notify ? 'Mute reminders' : 'Unmute reminders'}
                  aria-label={link.notify ? 'Mute reminders' : 'Unmute reminders'}
                  className="text-on-surface-variant hover:text-on-surface transition-colors shrink-0"
                >
                  {link.notify ? <Bell className="w-5 h-5" /> : <BellOff className="w-5 h-5 opacity-50" />}
                </button>
              </div>

              <p className="text-sm text-on-surface-variant mb-4">
                <span className="font-medium text-on-surface">Next:</span>{' '}
                {nextDoseLabel(link)}
              </p>

              <Link
                href={`/care/${encodeURIComponent(link.user_id)}`}
                className="text-sm font-medium text-primary hover:underline"
              >
                Manage medicines →
              </Link>
            </Card>
          ))}
        </div>
      )}
    </section>
  );
}