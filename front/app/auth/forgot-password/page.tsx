'use client';

import { useState } from 'react';
import { Button } from '@/components/button';
import { Input } from '@/components/input';
import { Card } from '@/components/card';
import { Logo } from '@/components/Logo';
import Link from 'next/link';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

export default function ForgotPassword() {
  const [email, setEmail] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetch(`${API_URL}/api/auth/forgot-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email })
      });

      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.detail || 'Something went wrong. Please try again.');
      }

      setSubmitted(true);
    } catch (err: any) {
      setError(err.message || 'Something went wrong. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-[var(--color-background)] min-h-[calc(100vh-64px)] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      {/* React 19 hoists these to <head>; the page is client-side, so the
          Metadata API is not available here. */}
      <title>Forgot Password - MediStore</title>
      <meta name="description" content="Reset your MediStore password — enter your email and we will send you a reset link." />
      <div className="w-full max-w-md">

        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <Logo variant="mark" size="lg" />
          </div>
          <h2 className="text-3xl font-extrabold text-[var(--color-ink)] font-heading mb-2">Forgot Password</h2>
          <p className="text-[var(--color-ink-variant)] text-sm">
            Enter your email and we'll send you a link to reset your password
          </p>
        </div>

        <Card className="p-8 shadow-sm">
          {submitted ? (
            <div className="text-center space-y-4">
              <div className="w-12 h-12 mx-auto bg-[var(--color-ok-container)] rounded-full flex items-center justify-center">
                <span className="text-[var(--color-ok)] text-2xl">✓</span>
              </div>
              <p className="text-[var(--color-ink)] font-medium">Check your inbox</p>
              <p className="text-[var(--color-ink-variant)] text-sm">
                If an account exists for <span className="font-medium">{email}</span>,
                we've sent a password reset link. The link expires in 30 minutes.
              </p>
              <Link href="/auth/login" className="inline-block text-sm font-medium text-[var(--color-primary)] hover:text-[var(--color-primary-hover)] transition-colors">
                Back to sign in
              </Link>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-6">
              <Input
                label="Email Address"
                name="email"
                type="email"
                placeholder="you@example.com"
                value={email}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setEmail(e.target.value)}
                required
              />

              {error && (
                <p className="text-[var(--color-alert)] text-sm">{error}</p>
              )}

              <Button type="submit" className="w-full py-3" disabled={loading}>
                {loading ? 'Sending...' : 'Send Reset Link'}
              </Button>

              <div className="text-center text-sm text-[var(--color-ink-variant)]">
                Remembered your password?{' '}
                <Link href="/auth/login" className="font-medium text-[var(--color-primary)] hover:text-[var(--color-primary-hover)] transition-colors">
                  Sign in
                </Link>
              </div>
            </form>
          )}
        </Card>
      </div>
    </div>
  );
}