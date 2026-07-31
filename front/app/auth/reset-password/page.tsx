'use client';

import { Suspense, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Button } from '@/components/button';
import { Input } from '@/components/input';
import { Card } from '@/components/card';
import Link from 'next/link';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

function ResetPasswordForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const token = searchParams.get('token') || '';

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
            Choose a new password for your account
          </p>
        </div>

        <Card className="p-8 shadow-sm">
          {!token ? (
            <div className="text-center space-y-4">
              <p className="text-text-main font-medium">Invalid reset link</p>
              <p className="text-subtext text-sm">
                This link is missing its reset token. Please use the link from your email,
                or request a new one.
              </p>
              <Link href="/auth/forgot-password" className="inline-block text-sm font-medium text-primary hover:text-blue-700 transition-colors">
                Request a new link
              </Link>
            </div>
          ) : success ? (
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

              <div className="text-center text-sm text-subtext">
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
