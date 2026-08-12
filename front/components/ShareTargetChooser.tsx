'use client';

import { useState } from 'react';

// The MediStore *app* can read a shared record too, so a recipient who holds
// the QR or link gets the choice instead of being locked to this website
// reader. Point NEXT_PUBLIC_APP_URL at the deployed app when it differs from
// this default.
const APP_URL =
  process.env.NEXT_PUBLIC_APP_URL || 'https://front-medistore-app.vercel.app';

export default function ShareTargetChooser({
  token,
  kind,
}: {
  token: string;
  kind: 'all' | 'report';
}) {
  const [dismissed, setDismissed] = useState(false);
  if (dismissed) return null;

  const appHref = `${APP_URL}/share/${kind === 'all' ? 'qr-code/' : ''}${token}`;

  return (
    <div className="mb-6 rounded-xl border border-primary/30 bg-primary/5 p-4">
      <div className="flex flex-col sm:flex-row sm:items-center gap-3">
        <div className="flex-1 min-w-0">
          <p className="font-semibold text-text-main">View this in the MediStore app</p>
          <p className="text-subtext text-sm">
            Open the shared record in the app, or keep browsing on this website.
          </p>
        </div>
        <div className="flex gap-2 shrink-0">
          <a
            href={appHref}
            className="px-4 py-2 rounded-lg bg-primary text-white font-medium text-sm hover:bg-primary/90 transition-colors"
          >
            Open in App
          </a>
          <button
            onClick={() => setDismissed(true)}
            className="px-4 py-2 rounded-lg border border-gray-300 text-gray-700 font-medium text-sm hover:bg-white transition-colors"
          >
            Keep on Website
          </button>
        </div>
      </div>
    </div>
  );
}