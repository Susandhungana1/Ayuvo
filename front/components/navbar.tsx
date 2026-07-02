'use client';

import Link from 'next/link';
import { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from './button';

const primaryLinks = [
  { href: '/dashboard', label: 'Dashboard' },
  { href: '/reports', label: 'Reports' },
  { href: '/medicines', label: 'Medicines' },
  { href: '/vitals', label: 'Vitals' },
];

const moreLinks = [
  { href: '/appointments', label: 'Appointments' },
  { href: '/emergency', label: 'Emergency ID' },
  { href: '/timeline', label: 'Timeline' },
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
  const [moreOpen, setMoreOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [isDoctor, setIsDoctor] = useState(false);
  const moreRef = useRef<HTMLDivElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const token = localStorage.getItem('token');
    const userData = localStorage.getItem('user');
    setIsLoggedIn(!!token);
    if (userData) {
      try {
        const user = JSON.parse(userData);
        setIsDoctor(user.role === 'DOCTOR');
      } catch {}
    }

    const handleStorageChange = () => {
      const t = localStorage.getItem('token');
      const u = localStorage.getItem('user');
      setIsLoggedIn(!!t);
      if (u) {
        try {
          const user = JSON.parse(u);
          setIsDoctor(user.role === 'DOCTOR');
        } catch {}
      }
    };

    window.addEventListener('storage', handleStorageChange);
    window.addEventListener('localStorageUpdated', handleStorageChange);
    return () => {
      window.removeEventListener('storage', handleStorageChange);
      window.removeEventListener('localStorageUpdated', handleStorageChange);
    };
  }, []);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (moreRef.current && !moreRef.current.contains(e.target as Node)) {
        setMoreOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  useEffect(() => {
    if (searchOpen && searchRef.current) {
      searchRef.current.focus();
    }
  }, [searchOpen]);

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setIsLoggedIn(false);
    router.push('/');
    setMobileMenuOpen(false);
  };

  const handleSearch = (e: React.KeyboardEvent | React.FormEvent) => {
    e.preventDefault();
    if (searchQuery.trim()) {
      router.push(`/search?q=${encodeURIComponent(searchQuery.trim())}`);
      setSearchOpen(false);
      setSearchQuery('');
      setMobileMenuOpen(false);
    }
  };

  const navLinks = isDoctor ? doctorLinks : primaryLinks;
  const moreNavLinks = isDoctor ? [] : moreLinks;

  return (
    <nav className="w-full bg-white shadow-sm border-b border-gray-100 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16 items-center gap-2">
          {/* Logo */}
          <div className="flex-shrink-0 flex items-center">
            <Link href="/" className="flex items-center gap-2">
              <div className="w-8 h-8 bg-primary rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-xl">+</span>
              </div>
              <span className="font-bold text-xl text-text-main tracking-tight">HealthTracker</span>
            </Link>
          </div>

          {/* Desktop Navigation */}
          {isLoggedIn && (
            <div className="hidden lg:flex items-center gap-6">
              {navLinks.map((link) => (
                <Link key={link.href} href={link.href} className="text-subtext hover:text-primary transition-colors font-medium text-sm whitespace-nowrap">
                  {link.label}
                </Link>
              ))}
              {moreNavLinks.length > 0 && (
                <div className="relative" ref={moreRef}>
                  <button
                    onClick={() => setMoreOpen(!moreOpen)}
                    className="text-subtext hover:text-primary transition-colors font-medium text-sm flex items-center gap-1"
                  >
                    More
                    <svg className={`w-3 h-3 transition-transform ${moreOpen ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {moreOpen && (
                    <div className="absolute right-0 mt-2 w-48 bg-white rounded-lg shadow-lg border border-gray-100 py-2">
                      {moreNavLinks.map((link) => (
                        <Link
                          key={link.href}
                          href={link.href}
                          onClick={() => setMoreOpen(false)}
                          className="block px-4 py-2 text-sm text-subtext hover:text-primary hover:bg-gray-50 transition-colors"
                        >
                          {link.label}
                        </Link>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Right side */}
          <div className="flex items-center gap-1 sm:gap-3">
            {isLoggedIn && (
              <>
                {/* Search - desktop */}
                <div className="hidden sm:block">
                  {searchOpen ? (
                    <form onSubmit={handleSearch} className="flex items-center gap-1">
                      <input
                        ref={searchRef}
                        type="text"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        placeholder="Search reports, medicines..."
                        className="w-40 lg:w-56 h-9 rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                        onBlur={() => { if (!searchQuery) setSearchOpen(false); }}
                      />
                      <button type="submit" className="p-1.5 text-gray-400 hover:text-primary" title="Search">
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                        </svg>
                      </button>
                    </form>
                  ) : (
                    <button onClick={() => setSearchOpen(true)} className="p-2 text-gray-400 hover:text-primary" title="Search">
                      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                      </svg>
                    </button>
                  )}
                </div>

                {/* Logout - desktop */}
                <button onClick={handleLogout} className="hidden sm:block text-red-500 hover:text-red-700 font-medium transition-colors text-sm whitespace-nowrap">
                  Logout
                </button>
              </>
            )}

            {!isLoggedIn && (
              <>
                <Link href="/auth/login" className="text-text-main hover:text-primary font-medium transition-colors hidden sm:block text-sm">
                  Log in
                </Link>
                <Link href="/auth/register">
                  <Button variant="primary" className="text-sm">Get Started</Button>
                </Link>
              </>
            )}

            {/* Mobile Menu Button */}
            <button className="lg:hidden p-2" onClick={() => setMobileMenuOpen(!mobileMenuOpen)} aria-label="Toggle menu">
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
          <div className="lg:hidden border-t border-gray-100 py-4">
            {/* Search in mobile */}
            <form onSubmit={handleSearch} className="mb-4 px-2">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search reports, medicines..."
                  className="flex-1 h-10 rounded-md border border-gray-300 bg-gray-50 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                />
                <button type="submit" className="bg-primary text-white px-4 py-2 rounded-md text-sm font-medium">
                  Search
                </button>
              </div>
            </form>

            <div className="flex flex-col space-y-1">
              {(isDoctor ? doctorLinks : [...primaryLinks, ...moreLinks]).map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  className="text-subtext hover:text-primary hover:bg-gray-50 transition-colors font-medium py-2.5 px-3 rounded-md"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  {link.label}
                </Link>
              ))}
              <div className="pt-3 mt-2 border-t border-gray-100">
                {isLoggedIn ? (
                  <button onClick={handleLogout} className="text-red-500 hover:text-red-700 hover:bg-red-50 font-medium text-left py-2.5 px-3 rounded-md w-full transition-colors">
                    Logout
                  </button>
                ) : (
                  <div className="flex flex-col space-y-2 px-1">
                    <Link href="/auth/login" onClick={() => setMobileMenuOpen(false)} className="text-center py-2 text-text-main hover:text-primary font-medium">
                      Log in
                    </Link>
                    <Link href="/auth/register" onClick={() => setMobileMenuOpen(false)}>
                      <Button variant="primary" className="w-full">Get Started</Button>
                    </Link>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </nav>
  );
}
