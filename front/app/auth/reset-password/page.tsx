'use client';

import { Suspense, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Button } from '@/components/button';
import { Input } from '@/components/input';
import { Card } from '@/components/card';
import Link from 'next/link';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

/** Accept either a bare code or a whole reset URL — people often copy the
 *  entire link out of the email rather than just the token. */
function extractToken(raw: string): string {
  const trimmed = raw.trim();
  const fromUrl = trimmed.match(/[?&]token=([A-Za-z0-9_-]+)/);
  return fromUrl ? fromUrl[1] : trimmed;
}

function ResetPasswordForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const urlToken = searchParams.get('token') || '';

  // Falls back to a pasted code when the emailed link didn't carry one.
  const [manualToken, setManualToken] = useState('');
  const token = urlToken || extractToken(manualToken);

  const [formData, setFormData] = useState({
    password: '',
    confirmPassword: ''
  });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!token) {
      setError('Paste the reset code from your email first');
      return;
    }
    if (formData.password.length < 8) {
      setError('Password must be at least 8 characters');
      return;
    }
    if (formData.password !== formData.confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    setLoading(true);
    try {
      const res = await fetch(`${API_URL}/api/auth/reset-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          token,
          new_password: formData.password
        })
      });

      const data = await res.json().catch(() => ({}));

      if (!res.ok) {
        throw new Error(data.detail || 'Failed to reset password');
      }

      setSuccess(true);
      setTimeout(() => router.push('/auth/login'), 2500);
    } catch (err: any) {
      setError(err.message || 'Failed to reset password');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-background min-h-[calc(100vh-64px)] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="w-full max-w-md">

        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <div className="w-12 h-12 bg-primary rounded-xl flex items-center justify-center">
              <span className="text-white font-bold text-3xl">+</span>
            </div>
          </div>
          <h2 className="text-3xl font-extrabold text-text-main mb-2">Reset Password</h2>
          <p className="text-subtext text-sm">
            {urlToken
              ? 'Choose a new password for your account'
              : 'Paste the code from your reset email, then choose a new password'}
          </p>
        </div>

        <Card className="p-8 shadow-sm">
          {success ? (
            <div className="text-center space-y-4">
              <div className="w-12 h-12 mx-auto bg-green-100 rounded-full flex items-center justify-center">
                <span className="text-green-600 text-2xl">✓</span>
              </div>
              <p className="text-text-main font-medium">Password updated</p>
              <p className="text-subtext text-sm">
                Your password has been reset. Redirecting you to sign in...
              </p>
              <Link href="/auth/login" className="inline-block text-sm font-medium text-primary hover:text-blue-700 transition-colors">
                Sign in now
              </Link>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-6">
              {!urlToken && (
                <Input
                  label="Reset Code"
                  name="manualToken"
                  type="text"
                  placeholder="Paste the code (or the whole link) from your email"
                  value={manualToken}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) => setManualToken(e.target.value)}
                  required
                />
              )}

              <Input
                label="New Password"
                name="password"
                type="password"
                placeholder="••••••••"
                value={formData.password}
                onChange={handleChange}
                required
              />

              <Input
                label="Confirm New Password"
                name="confirmPassword"
                type="password"
                placeholder="••••••••"
                value={formData.confirmPassword}
                onChange={handleChange}
                required
              />

              {error && (
                <p className="text-red-500 text-sm">{error}</p>
              )}

              <Button type="submit" className="w-full py-3" disabled={loading}>
                {loading ? 'Resetting...' : 'Reset Password'}
              </Button>

              <div className="text-center text-sm text-subtext space-x-4">
                <Link href="/auth/forgot-password" className="font-medium text-primary hover:text-blue-700 transition-colors">
                  Request a new link
                </Link>
                <Link href="/auth/login" className="font-medium text-primary hover:text-blue-700 transition-colors">
                  Back to sign in
                </Link>
              </div>
            </form>
          )}
        </Card>
      </div>
    </div>
  );
}

export default function ResetPassword() {
  return (
    <Suspense>
      <ResetPasswordForm />
    </Suspense>
  );
}
