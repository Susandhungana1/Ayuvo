'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Input } from '@/components/input';
import { Card } from '@/components/card';
import { Logo } from '@/components/Logo';
import { API_URL, storeSession } from '@/lib/api';
import Link from 'next/link';



export default function Login() {
  const router = useRouter();
  const [formData, setFormData] = useState({
    email: '',
    password: ''
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
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
          password: formData.password
        })
      });

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.detail || 'Login failed');
      }

      storeSession({ token: data.token, refresh_token: data.refresh_token, user: { id: data.id, name: data.name, email: data.email, role: data.role } });
      const next = new URLSearchParams(window.location.search).get('next');
      const safeNext = next?.startsWith('/') && !next.startsWith('//') ? next : '/';
      router.push(safeNext);
    } catch (err: any) {
      setError(err.message || 'Invalid email or password');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-[var(--color-background)] min-h-[calc(100vh-64px)] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      {/* React 19 hoists these to <head>; the page is client-side, so the
          Metadata API is not available here. */}
      <title>Sign In - MediStore</title>
      <meta name="description" content="Sign in to MediStore to access your digital health vault — vitals, medicines, reports, and appointments." />
      <div className="w-full max-w-md">
        
        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <Logo variant="mark" size="lg" />
          </div>
          <h2 className="text-3xl font-extrabold text-[var(--color-ink)] font-heading mb-2">Welcome Back</h2>
          <p className="text-[var(--color-ink-variant)] text-sm">
            Sign in to access your digital health vault
          </p>
        </div>

        <Card className="p-8 shadow-sm">
          <form onSubmit={handleSubmit} className="space-y-6">
            <Input 
              label="Email Address"
              name="email"
              type="email"
              autoComplete="email"
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
                autoComplete="current-password"
                placeholder="••••••••"
                value={formData.password}
                onChange={handleChange}
                required
              />
              <div className="flex justify-end pt-1">
                <Link href="/auth/forgot-password" className="text-sm font-medium text-[var(--color-primary)] hover:text-[var(--color-primary-hover)] transition-colors">
                  Forgot password?
                </Link>
              </div>
            </div>

            {error && (
              <p className="text-[var(--color-alert)] text-sm">{error}</p>
            )}

            <Button type="submit" className="w-full py-3" disabled={loading}>
              {loading ? 'Signing in...' : 'Sign In'}
            </Button>
          </form>

          <div className="mt-8 relative">
            <div className="absolute inset-0 flex items-center" aria-hidden="true">
              <div className="w-full border-t border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)]"></div>
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-2 bg-white dark:bg-[var(--color-card)] text-[var(--color-ink-muted)]">Or</span>
            </div>
          </div>

          <div className="mt-8 text-center text-sm text-[var(--color-ink-variant)]">
            Don't have an account?{' '}
            <Link href="/auth/register" className="font-medium text-[var(--color-primary)] hover:text-[var(--color-primary-hover)] transition-colors">
              Create one now
            </Link>
          </div>
        </Card>
      </div>
    </div>
  );
}