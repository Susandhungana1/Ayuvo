'use client';

import Link from 'next/link';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from './button';

const patientLinks = [
  { href: '/dashboard', label: 'Dashboard' },
  { href: '/appointments', label: 'Appointments' },
  { href: '/reports', label: 'Reports' },
  { href: '/medicines', label: 'Medicines' },
  { href: '/share', label: 'Share' },
];

const doctorLinks = [
  { href: '/dashboard', label: 'Dashboard' },
  { href: '/doctor/appointments', label: 'Appointments' },
  { href: '/doctor/availability', label: 'Availability' },
];

export function Navbar() {
  const router = useRouter();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [isDoctor, setIsDoctor] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('token');
    const userData = localStorage.getItem('user');
    setIsLoggedIn(!!token);
    
    if (userData) {
      const user = JSON.parse(userData);
      setIsDoctor(user.role === 'DOCTOR');
    }

    const handleStorageChange = () => {
      const token = localStorage.getItem('token');
      const userData = localStorage.getItem('user');
      setIsLoggedIn(!!token);
      if (userData) {
        const user = JSON.parse(userData);
        setIsDoctor(user.role === 'DOCTOR');
      }
    };

    window.addEventListener('storage', handleStorageChange);
    window.addEventListener('localStorageUpdated', handleStorageChange);
    
    return () => {
      window.removeEventListener('storage', handleStorageChange);
      window.removeEventListener('localStorageUpdated', handleStorageChange);
    };
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setIsLoggedIn(false);
    router.push('/');
    setMobileMenuOpen(false);
  };

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

          {/* Navigation Links (Desktop) - Only show when logged in */}
          {isLoggedIn && (
            <div className="hidden md:flex space-x-8">
              {(isDoctor ? doctorLinks : patientLinks).map((link) => (
                <Link key={link.href} href={link.href} className="text-subtext hover:text-primary transition-colors font-medium">
                  {link.label}
                </Link>
              ))}
            </div>
          )}

          {/* Auth Actions */}
          <div className="flex items-center space-x-2 sm:space-x-4">
            {isLoggedIn ? (
              <button
                onClick={handleLogout}
                className="text-red-500 hover:text-red-700 font-medium transition-colors"
              >
                Logout
              </button>
            ) : (
              <>
                <Link href="/auth/login" className="text-text-main hover:text-primary font-medium transition-colors hidden sm:block">
                  Log in
                </Link>
                <Link href="/auth/register">
                  <Button variant="primary">Get Started</Button>
                </Link>
              </>
            )}

            {/* Mobile Menu Button */}
            <button
              className="md:hidden p-2"
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              aria-label="Toggle menu"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                {mobileMenuOpen ? (
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                ) : (
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                )}
              </svg>
            </button>
          </div>
        </div>

        {/* Mobile Menu */}
        {mobileMenuOpen && (
          <div className="md:hidden border-t border-gray-100 py-4">
            <div className="flex flex-col space-y-4">
              {isLoggedIn && (isDoctor ? doctorLinks : patientLinks).map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  className="text-subtext hover:text-primary transition-colors font-medium py-2"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  {link.label}
                </Link>
              ))}
              <div className="flex flex-col space-y-2 pt-2 border-t border-gray-100">
                {isLoggedIn ? (
                  <button
                    onClick={handleLogout}
                    className="text-red-500 hover:text-red-700 font-medium text-left py-2"
                  >
                    Logout
                  </button>
                ) : (
                  <>
                    <Link href="/auth/login" className="text-text-main hover:text-primary font-medium" onClick={() => setMobileMenuOpen(false)}>
                      Log in
                    </Link>
                    <Link href="/auth/register" onClick={() => setMobileMenuOpen(false)}>
                      <Button variant="primary">Get Started</Button>
                    </Link>
                  </>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </nav>
  );
}
