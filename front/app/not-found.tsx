import Link from 'next/link';
import { Button } from '@/components/button';
import { Logo } from '@/components/Logo';

export default function NotFound() {
  return (
    <div className="min-h-[70vh] bg-[var(--color-bg)] flex items-center justify-center px-4">
      <div className="text-center max-w-md">
        <div className="flex justify-center mb-6">
          <Logo variant="mark" size="lg" />
        </div>
        <p className="text-[var(--color-primary)] font-semibold text-sm mb-2">404</p>
        <h1 className="text-3xl font-bold text-[var(--color-ink)] font-heading mb-3">
          Page not found
        </h1>
        <p className="text-[var(--color-ink-variant)] mb-8">
          The page you are looking for does not exist, may have been moved,
          or its share link has expired.
        </p>
        <div className="flex items-center justify-center gap-3">
          <Link href="/">
            <Button variant="primary">Back to Home</Button>
          </Link>
          <Link href="/auth/login">
            <Button variant="outline">Sign In</Button>
          </Link>
        </div>
      </div>
    </div>
  );
}