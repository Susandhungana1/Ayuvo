import Link from 'next/link';
import { Button } from './button';

export function Navbar() {
  return (
    <nav className="w-full bg-white shadow-sm border-b border-gray-100 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16 items-center">
          {/* Logo */}
          <div className="flex-shrink-0 flex items-center">
            <Link href="/" className="flex items-center gap-2">
              <div className="w-8 h-8 bg-primary rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-xl">+</span>
              </div>
              <span className="font-bold text-xl text-text-main tracking-tight">HealthTracker</span>
            </Link>
          </div>

          {/* Navigation Links (Desktop) */}
          <div className="hidden md:flex space-x-8">
            <Link href="/" className="text-subtext hover:text-primary transition-colors font-medium">Home</Link>
            <Link href="/about" className="text-subtext hover:text-primary transition-colors font-medium">About</Link>
            <Link href="/contact" className="text-subtext hover:text-primary transition-colors font-medium">Contact</Link>
            <Link href="/blog" className="text-subtext hover:text-primary transition-colors font-medium">Blog</Link>
          </div>

          {/* Auth Actions */}
          <div className="flex items-center space-x-4">
            <Link href="/auth/login" className="text-text-main hover:text-primary font-medium transition-colors hidden sm:block">
              Log in
            </Link>
            <Link href="/auth/register">
              <Button variant="primary">Get Started</Button>
            </Link>
          </div>
        </div>
      </div>
    </nav>
  );
}
