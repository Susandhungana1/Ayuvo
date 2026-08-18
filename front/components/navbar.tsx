'use client';

import Link from 'next/link';
import { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from './button';
import { ThemeToggle } from './theme-toggle';
import { LanguageToggle } from './language-toggle';
import { Logo } from './Logo';
import { useI18n } from '@/lib/i18n';
import { clearSession } from '@/lib/api';

const primaryLinks = [
  { href: '/', tKey: 'nav.home' },
  { href: '/dashboard', tKey: 'nav.dashboard' },
  { href: '/reports', tKey: 'nav.reports' },
  { href: '/medicines', tKey: 'nav.medicines' },
  { href: '/vitals', tKey: 'nav.vitals' },
];

const moreLinks = [
  { href: '/appointments', tKey: 'nav.appointments' },
  { href: '/emergency', tKey: 'nav.emergency' },
  { href: '/settings/caretakers', tKey: 'nav.caretakers' },
  { href: '/settings', tKey: 'nav.settings' },
  { href: '/nearby', tKey: 'nav.nearby' },
  { href: '/timeline', tKey: 'nav.timeline' },
  { href: '/share', tKey: 'nav.share' },
];

const doctorLinks = [
  { href: '/', tKey: 'nav.home' },
  { href: '/dashboard', tKey: 'nav.dashboard' },
  { href: '/doctor/appointments', tKey: 'nav.appointments' },
  { href: '/doctor/availability', tKey: 'nav.availability' },
];

const companyLinks = [
  { href: '/about', tKey: 'nav.about' },
  { href: '/contact', tKey: 'nav.contact' },
  { href: '/faq', tKey: 'nav.faq' },
  { href: '/privacy', tKey: 'nav.privacy' },
  { href: '/terms', tKey: 'nav.terms' },
];

export function Navbar() {
  const router = useRouter();
  const { t } = useI18n();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [moreOpen, setMoreOpen] = useState(false);
  const [companyOpen, setCompanyOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [isDoctor, setIsDoctor] = useState(false);
  const moreRef = useRef<HTMLDivElement>(null);
  const companyRef = useRef<HTMLDivElement>(null);
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
      if (companyRef.current && !companyRef.current.contains(e.target as Node)) {
        setCompanyOpen(false);
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
    // Best-effort: revoke the refresh token server-side so a stolen pair
    // dies; if the access token already expired the call 401s, and logout
    // still proceeds locally.
    const token = localStorage.getItem('token');
    const refreshToken = localStorage.getItem('refresh_token');
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001';
    if (token && refreshToken) {
      fetch(`${apiUrl}/api/auth/logout`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ refresh_token: refreshToken }),
      }).catch(() => {});
    }
    clearSession();
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
    <nav className="w-full bg-white dark:bg-[var(--color-card)] border-b border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16 items-center gap-2">
          {/* Logo */}
          <div className="flex-shrink-0 flex items-center">
            <Logo variant="full" size="md" />
          </div>

          {/* Desktop Navigation */}
          {isLoggedIn && (
            <div className="hidden lg:flex items-center gap-6">
              {navLinks.map((link) => (
                <Link key={link.href} href={link.href} className="text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] transition-colors font-medium text-sm whitespace-nowrap">
                  {t(link.tKey)}
                </Link>
              ))}
              {moreNavLinks.length > 0 && (
                <div className="relative" ref={moreRef}>
                  <button
                    onClick={() => setMoreOpen(!moreOpen)}
                    className="text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] transition-colors font-medium text-sm flex items-center gap-1"
                  >
                    {t('nav.more')}
                    <svg className={`w-3 h-3 transition-transform ${moreOpen ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {moreOpen && (
                    <div className="absolute right-0 mt-2 w-48 bg-white dark:bg-[var(--color-card)] rounded-lg shadow-lg border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] py-2">
                      {moreNavLinks.map((link) => (
                        <Link
                          key={link.href}
                          href={link.href}
                          onClick={() => setMoreOpen(false)}
                          className="block px-4 py-2 text-sm text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] hover:bg-[var(--color-muted)] transition-colors"
                        >
                          {t(link.tKey)}
                        </Link>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Company links — always visible, signed in or not */}
          <div className="hidden lg:flex items-center gap-6">
            <div className="relative" ref={companyRef}>
              <button
                onClick={() => setCompanyOpen(!companyOpen)}
                className="text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] transition-colors font-medium text-sm flex items-center gap-1"
              >
                {t('nav.company')}
                <svg className={`w-3 h-3 transition-transform ${companyOpen ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                </svg>
              </button>
              {companyOpen && (
                <div className="absolute right-0 mt-2 w-48 bg-white dark:bg-[var(--color-card)] rounded-lg shadow-lg border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] py-2">
                  {companyLinks.map((link) => (
                    <Link
                      key={link.href}
                      href={link.href}
                      onClick={() => setCompanyOpen(false)}
                      className="block px-4 py-2 text-sm text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] hover:bg-[var(--color-muted)] transition-colors"
                    >
                      {t(link.tKey)}
                    </Link>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Right side */}
          <div className="flex items-center gap-1 sm:gap-3">
            <LanguageToggle />
            <ThemeToggle />
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
                        placeholder={t('nav.search')}
                        className="w-40 lg:w-56 h-9 rounded-[var(--radius-sm)] border border-[var(--color-outline)] bg-white dark:bg-[var(--color-card)] px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-focus)]"
                        onBlur={() => { if (!searchQuery) setSearchOpen(false); }}
                      />
                      <button type="submit" className="p-1.5 text-[var(--color-ink-muted)] hover:text-[var(--color-primary)]" title="Search">
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                        </svg>
                      </button>
                    </form>
                  ) : (
                    <button onClick={() => setSearchOpen(true)} className="p-2 text-[var(--color-ink-muted)] hover:text-[var(--color-primary)]" title="Search">
                      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                      </svg>
                    </button>
                  )}
                </div>

                {/* Logout - desktop */}
                <button onClick={handleLogout} className="hidden sm:block text-[var(--color-alert)] hover:text-[var(--color-alert-text)] font-medium transition-colors text-sm whitespace-nowrap">
                  {t('nav.logout')}
                </button>
              </>
            )}

            {!isLoggedIn && (
              <>
                <Link href="/auth/login" className="text-[var(--color-ink)] hover:text-[var(--color-primary)] font-medium transition-colors hidden sm:block text-sm">
                  {t('nav.login')}
                </Link>
                <Link href="/auth/register">
                  <Button variant="primary" className="text-sm">{t('nav.getStarted')}</Button>
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
          <div className="lg:hidden border-t border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] py-4">
            {/* Search in mobile */}
            <form onSubmit={handleSearch} className="mb-4 px-2">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder={t('nav.search')}
                  className="flex-1 h-10 rounded-[var(--radius-sm)] border border-[var(--color-outline)] bg-[var(--color-muted)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-focus)]"
                />
                <button type="submit" className="bg-[var(--color-primary)] text-white px-4 py-2 rounded-[var(--radius-sm)] text-sm font-medium">
                  Search
                </button>
              </div>
            </form>

            <div className="flex flex-col space-y-1">
              {(isDoctor ? doctorLinks : [...primaryLinks, ...moreLinks]).map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  className="text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] hover:bg-[var(--color-muted)] transition-colors font-medium py-2.5 px-3 rounded-[var(--radius-sm)]"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  {t(link.tKey)}
                </Link>
              ))}
              <div className="pt-3 mt-2 border-t border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)]">
                <p className="px-3 py-1.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-ink-muted)]">
                  {t('nav.company')}
                </p>
                {companyLinks.map((link) => (
                  <Link
                    key={link.href}
                    href={link.href}
                    className="text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] hover:bg-[var(--color-muted)] transition-colors font-medium py-2.5 px-3 rounded-[var(--radius-sm)]"
                    onClick={() => setMobileMenuOpen(false)}
                  >
                    {t(link.tKey)}
                  </Link>
                ))}
              </div>
              <div className="pt-3 mt-2 border-t border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)]">
                {isLoggedIn ? (
                  <button onClick={handleLogout} className="text-[var(--color-alert)] hover:text-[var(--color-alert-text)] hover:bg-[var(--color-alert-container)] font-medium text-left py-2.5 px-3 rounded-[var(--radius-sm)] w-full transition-colors">
                    {t('nav.logout')}
                  </button>
                ) : (
                  <div className="flex flex-col space-y-2 px-1">
                    <Link href="/auth/login" onClick={() => setMobileMenuOpen(false)} className="text-center py-2 text-[var(--color-ink)] hover:text-[var(--color-primary)] font-medium">
                      {t('nav.login')}
                    </Link>
                    <Link href="/auth/register" onClick={() => setMobileMenuOpen(false)}>
                      <Button variant="primary" className="w-full">{t('nav.getStarted')}</Button>
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