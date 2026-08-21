'use client';

import { useEffect, useState } from 'react';
import { apiFetch, API_URL } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { ShieldCheck, ShieldOff, KeyRound } from 'lucide-react';

/** Steps the enable flow walks through. */
type Stage = 'idle' | 'setup' | 'verify' | 'done';

interface SetupData {
  secret: string;
  otpauth_url: string;
  qr_code_data_uri: string;
}

/**
 * Two-factor authentication (TOTP) management for the signed-in user.
 *
 * Talks to the backend's /api/auth/2fa endpoints:
 *   GET  /2fa/status   -> { enabled }
 *   POST /2fa/setup    -> { secret, otpauth_url, qr_code_data_uri }
 *   POST /2fa/verify   -> { enabled }  (body: { code })
 *   POST /2fa/disable  -> { enabled }  (body: { code })
 *
 * The secret is generated server-side and only stored after the user confirms
 * a code, so abandoning a half-finished setup can never lock the account out.
 */
export function TwoFactorAuth() {
  const [enabled, setEnabled] = useState(false);
  const [statusLoading, setStatusLoading] = useState(true);
  const [stage, setStage] = useState<Stage>('idle');
  const [setup, setSetup] = useState<SetupData | null>(null);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await apiFetch(`${API_URL}/api/auth/2fa/status`);
        if (!res.ok) return;
        const data = await res.json();
        if (!cancelled) {
          setEnabled(Boolean(data.enabled));
          setStage(data.enabled ? 'done' : 'idle');
        }
      } catch {
        /* API unreachable — leave the section in its default state. */
      } finally {
        if (!cancelled) setStatusLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const beginSetup = async () => {
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const res = await apiFetch(`${API_URL}/api/auth/2fa/setup`, { method: 'POST' });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.detail || 'Failed to start setup');
      }
      const data = (await res.json()) as SetupData;
      setSetup(data);
      setStage('verify');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to start setup');
    } finally {
      setBusy(false);
    }
  };

  const confirmEnable = async () => {
    if (!code.trim()) {
      setError('Enter the 6-digit code from your authenticator app.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      const res = await apiFetch(`${API_URL}/api/auth/2fa/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: code.trim() }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.detail || 'Invalid code');
      }
      setEnabled(true);
      setStage('done');
      setSetup(null);
      setCode('');
      setNotice('Two-factor authentication is now on.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Invalid code');
    } finally {
      setBusy(false);
    }
  };

  const confirmDisable = async () => {
    if (!code.trim()) {
      setError('Enter a current 6-digit code to confirm.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      const res = await apiFetch(`${API_URL}/api/auth/2fa/disable`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: code.trim() }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.detail || 'Invalid code');
      }
      setEnabled(false);
      setStage('idle');
      setCode('');
      setNotice('Two-factor authentication is off.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Invalid code');
    } finally {
      setBusy(false);
    }
  };

  return (
    <Card className="p-lg">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h2 className="text-lg font-display font-semibold text-on-surface flex items-center gap-2">
            <ShieldCheck className="w-5 h-5 text-[var(--color-primary)]" aria-hidden="true" />
            Two-factor authentication
          </h2>
          <p className="text-sm text-on-surface-variant mt-1">
            Extra protection for your health records. Requires a code from your
            authenticator app when you sign in.
          </p>
        </div>
        {!statusLoading && (
          <span
            className={`inline-flex items-center gap-1.5 text-xs font-medium px-2.5 py-1 rounded-full shrink-0 ${
              enabled
                ? 'bg-[var(--color-ok-container)] text-[var(--color-ok)]'
                : 'bg-[var(--color-muted)] text-on-surface-variant'
            }`}
          >
            {enabled ? (
              <>
                <ShieldCheck className="w-3.5 h-3.5" aria-hidden="true" /> On
              </>
            ) : (
              <>
                <ShieldOff className="w-3.5 h-3.5" aria-hidden="true" /> Off
              </>
            )}
          </span>
        )}
      </div>

      {statusLoading ? (
        <div className="mt-4 h-5 bg-[var(--color-muted)] rounded animate-pulse w-40" />
      ) : (
        <>
          {error && (
            <p className="text-sm text-[var(--color-alert)] mt-4">{error}</p>
          )}
          {notice && (
            <p className="text-sm text-[var(--color-ok)] mt-4">{notice}</p>
          )}

          {stage === 'idle' && !enabled && (
            <div className="mt-4">
              <Button variant="primary" onClick={beginSetup} disabled={busy}>
                <KeyRound className="w-4 h-4 mr-2" aria-hidden="true" />
                {busy ? 'Preparing…' : 'Enable 2FA'}
              </Button>
            </div>
          )}

          {stage === 'verify' && setup && (
            <div className="mt-5 space-y-4">
              <p className="text-sm text-on-surface-variant">
                Scan this QR code with your authenticator app, then enter the
                code it shows to confirm.
              </p>
              <div className="flex flex-col sm:flex-row gap-5 items-start">
                {/* The backend returns the QR as a ready-to-render data URI. */}
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={setup.qr_code_data_uri}
                  alt="QR code for your authenticator app"
                  className="w-40 h-40 border border-[var(--color-outline)] rounded-lg bg-white"
                />
                <div className="flex-1 space-y-3">
                  <div>
                    <p className="text-xs font-medium text-on-surface-variant mb-1">
                      Or enter this key manually
                    </p>
                    <code className="block font-mono text-sm bg-[var(--color-surface-variant)] rounded px-3 py-2 break-all select-all">
                      {setup.secret}
                    </code>
                  </div>
                  <div className="max-w-xs">
                    <Input
                      label="6-digit code"
                      name="totp-code"
                      inputMode="numeric"
                      autoComplete="one-time-code"
                      maxLength={6}
                      placeholder="000000"
                      value={code}
                      onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                    />
                  </div>
                  <div className="flex gap-2">
                    <Button variant="primary" onClick={confirmEnable} disabled={busy}>
                      {busy ? 'Verifying…' : 'Confirm & enable'}
                    </Button>
                    <Button
                      variant="secondary"
                      onClick={() => {
                        setStage('idle');
                        setSetup(null);
                        setCode('');
                        setError('');
                      }}
                      disabled={busy}
                    >
                      Cancel
                    </Button>
                  </div>
                </div>
              </div>
            </div>
          )}

          {enabled && stage === 'done' && (
            <div className="mt-4 flex flex-col sm:flex-row sm:items-end gap-3">
              <div className="max-w-xs">
                <Input
                  label="Enter a current code to turn 2FA off"
                  name="totp-disable-code"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  maxLength={6}
                  placeholder="000000"
                  value={code}
                  onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                />
              </div>
              <Button variant="destructive" onClick={confirmDisable} disabled={busy}>
                {busy ? 'Turning off…' : 'Disable 2FA'}
              </Button>
            </div>
          )}
        </>
      )}
    </Card>
  );
}