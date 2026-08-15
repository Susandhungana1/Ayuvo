'use client';

/**
 * "Who has kept your records" — the accountability half of claiming.
 *
 * Anonymous link views can only ever be logged as an IP, so before claiming
 * existed a patient had no way to know who had read their reports. A claim has
 * a name attached, and this is where that name is shown — along with the means
 * to withdraw it.
 *
 * Renders nothing when there are no claims, so it stays out of the way for the
 * majority of users who have never been claimed.
 */

import { useEffect, useState } from 'react';
import { Card } from '@/components/card';
import { formatServerDateTime } from '@/lib/datetime';
import { ClaimOnMyRecords, listClaimsOnMyRecords, revokeClaim } from '@/lib/shares';

export function KeptByOthers() {
  const [claims, setClaims] = useState<ClaimOnMyRecords[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    listClaimsOnMyRecords()
      .then(setClaims)
      .catch(() => {
        // Silent: this is a secondary panel, and a user who cannot load it is
        // no worse off than one who has no claims at all.
      });
  }, []);

  const withdraw = async (claim: ClaimOnMyRecords) => {
    if (
      !confirm(
        `Withdraw ${claim.recipient_name}'s access? They will no longer be able to open these records. This cannot undo what they have already seen.`,
      )
    )
      return;
    try {
      await revokeClaim(claim.id);
      setClaims((c) => c.filter((x) => x.id !== claim.id));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not withdraw access');
    }
  };

  if (claims.length === 0) return null;

  return (
    <Card className="mt-8 p-4 sm:p-6">
      <h2 className="font-semibold text-text-main mb-1">
        Who has kept your records
      </h2>
      <p className="text-sm text-subtext mb-4">
        These people saved a share link to their account, so they keep access
        after the link expires. You can withdraw it at any time.
      </p>

      {error && (
        <p className="mb-3 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
          {error}
        </p>
      )}

      <ul className="space-y-2">
        {claims.map((claim) => (
          <li
            key={claim.id}
            className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-gray-100 px-3 py-2"
          >
            <div>
              <p className="font-medium text-text-main">{claim.recipient_name}</p>
              <p className="text-xs text-subtext">
                {claim.kind === 'all' ? 'Full medical record' : 'Single report'}
                {' · '}
                {claim.report_count} report{claim.report_count === 1 ? '' : 's'}
                {' · saved '}
                {formatServerDateTime(claim.claimed_at)}
              </p>
            </div>
            <button
              onClick={() => withdraw(claim)}
              className="rounded-lg border border-red-200 px-3 py-1.5 text-sm font-medium text-red-700 hover:bg-red-50"
            >
              Withdraw access
            </button>
          </li>
        ))}
      </ul>
    </Card>
  );
}
