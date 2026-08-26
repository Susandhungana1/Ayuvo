'use client';

import { useEffect, useRef, useState, useSyncExternalStore } from 'react';
import { useRouter } from 'next/navigation';
import { claimShare, isSignedIn, subscribeToSession } from '@/lib/shares';

/**
 * "Save to my account" on the public share reader.
 *
 * Claiming keeps what the link already shows, so it survives the link expiring.
 * It grants the recipient nothing new — the records are on screen in front of
 * them — but it does cost them their anonymity, and the copy is visible to the
 * sender, so the button says both things plainly rather than reading as a
 * frictionless "save".
 *
 * A signed-out visitor is the normal case (the token is the credential, so most
 * recipients arrive with no session). Sending them to /auth/login?next=… would
 * bring them back to the reader having forgotten why they left, so the intent
 * is parked in sessionStorage first and replayed on return. sessionStorage, not
 * localStorage: a stale intent must not fire days later on a shared computer.
 */

const PENDING_KEY = 'pendingShareClaim';

export default function ClaimShareButton({ token }: { token: string }) {
  const router = useRouter();
  const [state, setState] = useState<'idle' | 'saving' | 'saved' | 'error'>('idle');
  const [message, setMessage] = useState('');
  // The session lives in localStorage, which SSR cannot read. Subscribing to
  // it as an external store gives the server a defined snapshot (false) and
  // keeps the button honest if the token is cleared while the page is open —
  // both of which a useState+useEffect pair would get wrong.
  const signedIn = useSyncExternalStore(
    subscribeToSession,
    isSignedIn,
    () => false,
  );
  // Strict Mode double-invokes effects in dev; the ref keeps the replayed
  // claim to one request. The endpoint is idempotent anyway — this is just
  // hygiene, not correctness.
  const replayed = useRef(false);

  const succeeded = (reportCount: number) => {
    setState('saved');
    setMessage(
      reportCount === 1
        ? 'Saved. This report is now in your account.'
        : `Saved. ${reportCount} reports are now in your account.`,
    );
  };

  const failed = (err: unknown) => {
    setState('error');
    setMessage(err instanceof Error ? err.message : 'Could not save this share.');
  };

  const save = async () => {
    setState('saving');
    try {
      succeeded((await claimShare(token)).report_count);
    } catch (err) {
      failed(err);
    }
  };

  useEffect(() => {
    // Coming back from the login page with an intent parked for THIS token.
    if (replayed.current) return;
    if (sessionStorage.getItem(PENDING_KEY) !== token || !isSignedIn()) return;

    replayed.current = true;
    sessionStorage.removeItem(PENDING_KEY);

    // Deliberately not `save()`: that sets state synchronously inside the
    // effect body, which cascades a render. Settling only in the promise
    // callbacks costs a brief "Save to my account" flash before the result
    // lands, which is the right trade on a page that has just loaded.
    let cancelled = false;
    claimShare(token)
      .then((claim) => !cancelled && succeeded(claim.report_count))
      .catch((err) => !cancelled && failed(err));
    return () => {
      cancelled = true;
    };
  }, [token]);

  const signInThenSave = () => {
    sessionStorage.setItem(PENDING_KEY, token);
    router.push(`/auth/login?next=${encodeURIComponent(window.location.pathname)}`);
  };

  if (state === 'saved') {
    return (
      <div className="mb-6 rounded-xl border border-green-200 bg-green-50 p-4">
        <p className="font-medium text-green-800">{message}</p>
        <button
          onClick={() => router.push('/shared-with-me')}
          className="mt-2 text-sm font-medium text-green-700 underline hover:text-green-900"
        >
          View in Shared with me
        </button>
      </div>
    );
  }

  return (
    <div className="mb-6 rounded-xl border border-primary/20 bg-primary/5 p-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="min-w-[16rem] flex-1">
          <p className="font-semibold text-text-main">Keep these records</p>
          <p className="text-sm text-subtext">
            This link expires. Save it to your Ayuvo account to keep access
            afterwards — the sender will see that you saved it, and can withdraw
            it later.
          </p>
        </div>
        <button
          onClick={signedIn ? save : signInThenSave}
          disabled={state === 'saving'}
          className="shrink-0 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary/90 disabled:opacity-60"
        >
          {state === 'saving'
            ? 'Saving…'
            : signedIn
              ? 'Save to my account'
              : 'Sign in to save'}
        </button>
      </div>
      {state === 'error' && (
        <p className="mt-2 text-sm text-red-600">{message}</p>
      )}
    </div>
  );
}
