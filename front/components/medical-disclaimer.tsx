'use client';

/**
 * What this app is not, said once before anything is read.
 *
 * Ayuvo flags a lab value against a reference range and names the band a blood
 * pressure falls in. Both look like a verdict, and neither is one — the ranges
 * are typical-adult tables applied without knowing the reader's age,
 * pregnancy, medication or history.
 *
 * Shown on the first visit from this browser and never again. The same words
 * live on /settings, where they can be found on purpose rather than by
 * accident, and both read them from the constants below so the two cannot
 * drift apart.
 *
 * Not dismissible: no Escape, no backdrop click. An acknowledgement that can be
 * clicked away by accident has not been given.
 */

import { useCallback, useSyncExternalStore } from 'react';
import { Button } from '@/components/button';
import { Dialog } from '@/components/ui/dialog';

export const MEDICAL_DISCLAIMER_TITLE = 'Medical Disclaimer';

export const MEDICAL_DISCLAIMER_BODY =
  'Ayuvo provides educational summaries of your health records, not clinical ' +
  'diagnoses. Always consult a qualified healthcare professional for medical ' +
  'decisions.';

/** Versioned, so a future change to the wording can ask again. */
const STORAGE_KEY = 'ayuvo.disclaimer.v1';

/**
 * `localStorage` as an external store, read through `useSyncExternalStore`
 * rather than copied into state by an effect.
 *
 * The effect version renders the modal, then hides it a frame later on a
 * machine that has already accepted — a flash on every page load. This renders
 * the right answer on the client's first paint instead, and React handles the
 * server/client split through `getServerSnapshot`.
 */
const listeners = new Set<() => void>();

function subscribe(listener: () => void) {
  listeners.add(listener);
  // Another tab accepting it counts too.
  window.addEventListener('storage', listener);
  return () => {
    listeners.delete(listener);
    window.removeEventListener('storage', listener);
  };
}

/** Returns a string, not a boolean, so the snapshot compares stably by value. */
function getSnapshot(): string {
  try {
    return localStorage.getItem(STORAGE_KEY) === 'true' ? 'accepted' : 'pending';
  } catch {
    // Private mode, or storage blocked entirely. Showing it every visit is the
    // safe failure: the alternative is never showing it at all.
    return 'pending';
  }
}

/** There is no browser during SSR, and a modal in the prerendered HTML would
 *  be markup the client immediately disagrees with. */
const getServerSnapshot = (): string => 'accepted';

export function MedicalDisclaimer() {
  const status = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  const accept = useCallback(() => {
    try {
      localStorage.setItem(STORAGE_KEY, 'true');
    } catch {
      /* Nothing to do — it will be shown again, which is the safe direction. */
    }
    for (const listener of listeners) listener();
  }, []);

  return (
    <Dialog
      open={status === 'pending'}
      onClose={accept}
      dismissible={false}
      title={MEDICAL_DISCLAIMER_TITLE}
      footer={
        <Button variant="primary" onClick={accept} autoFocus>
          I understand
        </Button>
      }
    >
      <p className="text-sm leading-relaxed text-[var(--color-ink-variant)]">
        {MEDICAL_DISCLAIMER_BODY}
      </p>
    </Dialog>
  );
}
