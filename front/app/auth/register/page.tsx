'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Input } from '@/components/input';
import { Card } from '@/components/card';
import { Logo } from '@/components/Logo';
import Link from 'next/link';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

export default function Register() {
  const router = useRouter();
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    password: '',
    confirmPassword: ''
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (formData.password !== formData.confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    setLoading(true);

    try {
      const res = await fetch(`${API_URL}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: formData.name,
          email: formData.email,
          password: formData.password
        })
      });

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.detail || 'Registration failed');
      }

      localStorage.setItem('token', data.token);
      localStorage.setItem('user', JSON.stringify(data));
      window.dispatchEvent(new Event('localStorageUpdated'));
      router.push('/');
    } catch (err: any) {
      setError(err.message || 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-[var(--color-background)] min-h-[calc(100vh-64px)] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="w-full max-w-md">
        
        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <Logo variant="mark" size="lg" />
          </div>
          <h2 className="text-3xl font-extrabold text-[var(--color-ink)] font-heading mb-2">Create an Account</h2>
          <p className="text-[var(--color-ink-variant)] text-sm">
            Join MediStore to securely manage your medical records
          </p>
        </div>

        <Card className="p-8 shadow-sm">
          <form onSubmit={handleSubmit} className="space-y-5">
            <Input 
              label="Full Name"
              name="name"
              type="text"
              placeholder="John Doe"
              value={formData.name}
              onChange={handleChange}
              required
            />
            
            <Input 
              label="Email Address"
              name="email"
              type="email"
              placeholder="you@example.com"
              value={formData.email}
              onChange={handleChange}
              required
            />
            
            <Input 
              label="Password"
              name="password"
              type="password"
              placeholder="Create a strong password"
              value={formData.password}
              onChange={handleChange}
              required
            />

            <Input 
              label="Confirm Password"
              name="confirmPassword"
              type="password"
              placeholder="Confirm your password"
              value={formData.confirmPassword}
              onChange={handleChange}
              required
            />

            {error && (
              <p className="text-[var(--color-alert)] text-sm">{error}</p>
            )}

            <div className="pt-2">
              <Button type="submit" className="w-full py-3" disabled={loading}>
                {loading ? 'Registering...' : 'Register'}
              </Button>
            </div>
            
            <p className="text-xs text-[var(--color-ink-variant)] text-center mt-4">
              By registering, you agree to our{' '}
              <a href="#" className="text-[var(--color-primary)] hover:underline">Terms of Service</a> and{' '}
              <a href="#" className="text-[var(--color-primary)] hover:underline">Privacy Policy</a>.
            </p>
          </form>

          <div className="mt-6 text-center text-sm text-[var(--color-ink-variant)] border-t border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] pt-6">
            Already have an account?{' '}
            <Link href="/auth/login" className="font-medium text-[var(--color-primary)] hover:text-[var(--color-primary-hover)] transition-colors">
              Sign in
            </Link>
          </div>
        </Card>
      </div>
    </div>
  );
}