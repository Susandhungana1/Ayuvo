'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { Lock } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface LoginResponse {
  id: string;
  name: string;
  email: string;
  role: string;
  token: string;
}

export default function Login() {
  const router = useRouter();
  const [formData, setFormData] = useState({
    email: '',
    password: ''
  });
  const [totp, setTotp] = useState('');
  const [needsTotp, setNeedsTotp] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const complete = (data: LoginResponse) => {
    localStorage.setItem('token', data.token);
    localStorage.setItem('user', JSON.stringify(data));
    window.dispatchEvent(new Event('localStorageUpdated'));
    // Pages that bounce here on an expired session pass the page they were
    // trying to reach as `?next=`, so signing in resumes where the user was
    // instead of dumping them on the home page to navigate back by hand.
    // Read from location rather than useSearchParams(), which would force
    // this page into a Suspense boundary to build.
    // Only same-origin paths: `//evil.com` is a valid URL to a foreign host,
    // so a bare startsWith('/') check would leave an open redirect that
    // phishes the login form's own users.
    const next = new URLSearchParams(window.location.search).get('next');
    const safeNext = next?.startsWith('/') && !next.startsWith('//') ? next : '/';
    router.push(safeNext);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetch(`${API_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          username: formData.email,
          password: formData.password,
          // The backend has no TOTP field in the OAuth2 form, so the 6-digit
          // code rides in `client_secret`. First attempt omits it; on 401 with
          // X-2FA-Required the form switches to the code stage and retries.
          ...(needsTotp ? { client_secret: totp } : {})
        })
      });

      const data = await res.json();

      if (!res.ok) {
        if (res.headers.get('x-2fa-required')) {
          setNeedsTotp(true);
          return;
        }
        throw new Error(data.detail || 'Login failed');
      }

      complete(data);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-surface min-h-[calc(100vh-64px)] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <div className="w-12 h-12 bg-primary rounded-xl flex items-center justify-center">
              <span className="text-on-primary font-bold text-3xl">+</span>
            </div>
          </div>
          <h2 className="text-3xl font-display font-bold text-on-surface mb-2">Welcome Back</h2>
          <p className="text-on-surface-variant text-sm">
            Sign in to access your digital health vault
          </p>
        </div>

        <Card className="p-xl">
          <form onSubmit={handleSubmit} className="space-y-6">
            {!needsTotp ? (
              <>
                <Input
                  label="Email Address"
                  name="email"
                  type="email"
                  placeholder="you@example.com"
                  value={formData.email}
                  onChange={handleChange}
                  required
                />

                <div className="space-y-1">
                  <Input
                    label="Password"
                    name="password"
                    type="password"
                    placeholder="••••••••"
                    value={formData.password}
                    onChange={handleChange}
                    required
                  />
                  <div className="flex justify-end pt-1">
                    <Link href="/auth/forgot-password" className="text-sm font-medium text-primary hover:underline transition-colors">
                      Forgot password?
                    </Link>
                  </div>
                </div>
              </>
            ) : (
              <div className="space-y-5">
                <div className="flex items-start gap-sm bg-primary/5 border border-primary/20 rounded-md p-md">
                  <div className="w-9 h-9 bg-primary/10 rounded-sm flex items-center justify-center shrink-0">
                    <Lock className="w-4 h-4 text-primary" />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-on-surface">Two-step verification</p>
                    <p className="text-xs text-on-surface-variant mt-0.5">
                      Enter the 6-digit code from your authenticator app.
                    </p>
                  </div>
                </div>
                <Input
                  label="Authentication Code"
                  name="totp"
                  type="text"
                  inputMode="numeric"
                  maxLength={6}
                  autoComplete="one-time-code"
                  placeholder="000000"
                  value={totp}
                  onChange={(e) => setTotp(e.target.value.replace(/\D/g, ''))}
                  required
                />
              </div>
            )}

            {error && (
              <p className="text-alert text-sm" role="alert">{error}</p>
            )}

            <Button type="submit" className="w-full" disabled={loading || (needsTotp && totp.length !== 6)}>
              {loading ? (needsTotp ? 'Verifying...' : 'Signing in...') : needsTotp ? 'Verify' : 'Sign In'}
            </Button>

            {needsTotp && (
              <button
                type="button"
                onClick={() => { setNeedsTotp(false); setTotp(''); setError(''); }}
                className="w-full text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors"
              >
                Back to sign in
              </button>
            )}
          </form>

          <div className="mt-xl relative">
            <div className="absolute inset-0 flex items-center" aria-hidden="true">
              <div className="w-full border-t border-outline"></div>
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-2 bg-surface-card text-on-surface-variant">Or</span>
            </div>
          </div>

          <div className="mt-xl text-center text-sm text-on-surface-variant">
            Don&apos;t have an account?{' '}
            <Link href="/auth/register" className="font-medium text-primary hover:underline transition-colors">
              Create one now
            </Link>
          </div>
        </Card>
      </div>
    </div>
  );
}