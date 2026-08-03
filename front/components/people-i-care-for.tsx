'use client';

/**
 * Dashboard section listing the people this user cares for.
 *
 * Renders nothing at all unless there is at least one active link, so the
 * dashboard is unchanged for everyone who isn't a caretaker.
 */

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { Card } from '@/components/card';
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

  const load = useCallback(async () => {
    try {
      setLinks(await listLinks('caretaker'));
    } catch {
      // Feature off, or offline — either way show nothing.
      setLinks([]);
    } finally {
      setReady(true);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleRedeem = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      await redeemInvite(code);
      setCode('');
      setAdding(false);
      load();
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
      load();
    }
  };

  if (!ready) return null;
  // Nothing to show and nothing being added: stay completely out of the way.
  if (links.length === 0 && !adding) {
    return (
      <div className="mt-10">
        <button
          onClick={() => setAdding(true)}
          className="text-sm text-subtext hover:text-primary transition-colors"
        >
          + Caring for someone? Enter their code
        </button>
      </div>
    );
  }

  return (
    <section className="mt-12">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-bold text-text-main">People I care for</h2>
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
        <Card className="p-5 mb-4">
          <form onSubmit={handleRedeem} className="flex flex-wrap items-end gap-3">
            <div className="flex flex-col gap-1.5 grow min-w-[200px]">
              <label htmlFor="care-code" className="text-sm font-medium text-gray-700">
                Their care code
              </label>
              <input
                id="care-code"
                value={code}
                onChange={(e) => setCode(e.target.value.toUpperCase())}
                placeholder="XXXX-XXXX"
                autoComplete="off"
                className="flex h-10 rounded-md border border-gray-300 bg-white px-3 py-2 font-mono tracking-widest text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
              />
            </div>
            <button
              type="submit"
              disabled={busy || !code.trim()}
              className="h-10 rounded-xl bg-primary px-5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
            >
              {busy ? 'Checking…' : 'Add'}
            </button>
            <button
              type="button"
              onClick={() => {
                setAdding(false);
                setError('');
              }}
              className="h-10 px-3 text-sm text-subtext hover:text-text-main"
            >
              Cancel
            </button>
          </form>
          {error && <p className="mt-3 text-sm text-red-600">{error}</p>}
        </Card>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {links.map((link) => (
          <Card key={link.id} className="p-5">
            <div className="flex items-start justify-between gap-2 mb-3">
              <div>
                <h3 className="font-semibold text-text-main">{link.name}</h3>
                <p className="text-xs text-subtext">
                  {link.medicine_count ?? 0} medicine
                  {link.medicine_count === 1 ? '' : 's'}
                </p>
              </div>
              <button
                onClick={() => toggleMute(link)}
                title={link.notify ? 'Mute reminders' : 'Unmute reminders'}
                aria-label={link.notify ? 'Mute reminders' : 'Unmute reminders'}
                className="text-lg leading-none shrink-0 hover:opacity-70"
              >
                {link.notify ? '🔔' : '🔕'}
              </button>
            </div>

            <p className="text-sm text-subtext mb-4">
              <span className="font-medium text-text-main">Next:</span>{' '}
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
    </section>
  );
}
