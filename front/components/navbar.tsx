'use client';

import Link from 'next/link';
import { useState, useEffect, useRef, useSyncExternalStore } from 'react';
import { useRouter } from 'next/navigation';
import { ChevronDown, LogOut, Menu, Search, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ThemeToggle } from './theme-toggle';
import { LanguageToggle } from './language-toggle';
import { useI18n } from '@/lib/i18n';
import { getSessionServerSnapshot, getSessionSnapshot, subscribeSession } from '@/lib/session';

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

export function Navbar() {
  const router = useRouter();
  const { t } = useI18n();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [moreOpen, setMoreOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const moreRef = useRef<HTMLDivElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);

  // Session read from localStorage (token + user), kept in sync across tabs
  // and with the auth pages via the `localStorageUpdated` event.
  const session = useSyncExternalStore(
    subscribeSession,
    getSessionSnapshot,
    getSessionServerSnapshot,
  );
  const isLoggedIn = !!session.token;
  const isDoctor = session.isDoctor;

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
    window.dispatchEvent(new Event('localStorageUpdated'));
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
    <nav className="w-full bg-surface-card border-b border-outline sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16 items-center gap-2">
          {/* Logo */}
          <div className="flex-shrink-0 flex items-center">
            <Link href="/" className="flex items-center gap-2">
              <div className="w-8 h-8 bg-primary rounded-sm flex items-center justify-center">
                <span className="text-on-primary font-bold text-xl">+</span>
              </div>
              <span className="font-bold text-xl font-display text-on-surface tracking-tight">MediStore</span>
            </Link>
          </div>

          {/* Desktop Navigation */}
          {isLoggedIn && (
            <div className="hidden lg:flex items-center gap-6">
              {navLinks.map((link) => (
                <Link key={link.href} href={link.href} className="text-on-surface-variant hover:text-primary transition-colors font-medium text-sm whitespace-nowrap">
                  {t(link.tKey)}
                </Link>
              ))}
              {moreNavLinks.length > 0 && (
                <div className="relative" ref={moreRef}>
                  <button
                    onClick={() => setMoreOpen(!moreOpen)}
                    className="text-on-surface-variant hover:text-primary transition-colors font-medium text-sm flex items-center gap-1"
                  >
                    {t('nav.more')}
                    <ChevronDown className={`w-3 h-3 transition-transform duration-fast ${moreOpen ? 'rotate-180' : ''}`} />
                  </button>
                  {moreOpen && (
                    <div className="absolute right-0 mt-2 w-48 bg-surface-card rounded-md shadow-pop border border-outline py-xs anim-pop-in">
                      {moreNavLinks.map((link) => (
                        <Link
                          key={link.href}
                          href={link.href}
                          onClick={() => setMoreOpen(false)}
                          className="block px-lg py-sm text-sm text-on-surface-variant hover:text-primary hover:bg-primary/5 transition-colors"
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
                        className="w-40 lg:w-56 h-9 rounded-sm border border-outline bg-surface-card px-3 py-1.5 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-focus-ring"
                        onBlur={() => { if (!searchQuery) setSearchOpen(false); }}
                      />
                      <button type="submit" className="p-1.5 text-on-surface-variant hover:text-primary transition-colors" title="Search" aria-label="Search">
                        <Search className="w-5 h-5" />
                      </button>
                    </form>
                  ) : (
                    <button onClick={() => setSearchOpen(true)} className="p-2 text-on-surface-variant hover:text-primary transition-colors" title="Search" aria-label="Search">
                      <Search className="w-5 h-5" />
                    </button>
                  )}
                </div>

                {/* Logout - desktop */}
                <button onClick={handleLogout} className="hidden sm:flex items-center gap-1.5 text-alert hover:text-error font-medium transition-colors text-sm whitespace-nowrap">
                  <LogOut className="w-4 h-4" />
                  {t('nav.logout')}
                </button>
              </>
            )}

            {!isLoggedIn && (
              <>
                <Link href="/auth/login" className="text-on-surface hover:text-primary font-medium transition-colors hidden sm:block text-sm">
                  {t('nav.login')}
                </Link>
                <Link href="/auth/register">
                  <Button size="sm">{t('nav.getStarted')}</Button>
                </Link>
              </>
            )}

            {/* Mobile Menu Button */}
            <button className="lg:hidden p-2 text-on-surface-variant hover:text-primary transition-colors" onClick={() => setMobileMenuOpen(!mobileMenuOpen)} aria-label="Toggle menu">
              {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
            </button>
          </div>
        </div>

        {/* Mobile Menu */}
        {mobileMenuOpen && (
          <div className="lg:hidden border-t border-outline py-lg">
            {/* Search in mobile */}
            <form onSubmit={handleSearch} className="mb-lg px-sm">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder={t('nav.search')}
                  className="flex-1 h-10 rounded-sm border border-outline bg-surface px-3 py-2 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-focus-ring"
                />
                <Button type="submit" size="sm">Search</Button>
              </div>
            </form>

            <div className="flex flex-col space-y-1">
              {(isDoctor ? doctorLinks : [...primaryLinks, ...moreLinks]).map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  className="text-on-surface-variant hover:text-primary hover:bg-primary/5 transition-colors font-medium py-2.5 px-3 rounded-sm"
                  onClick={() => setMobileMenuOpen(false)}
                >
                  {t(link.tKey)}
                </Link>
              ))}
              <div className="pt-3 mt-2 border-t border-outline">
                {isLoggedIn ? (
                  <button onClick={handleLogout} className="flex items-center gap-2 text-alert hover:text-error hover:bg-primary/5 font-medium text-left py-2.5 px-3 rounded-sm w-full transition-colors">
                    <LogOut className="w-4 h-4" />
                    {t('nav.logout')}
                  </button>
                ) : (
                  <div className="flex flex-col space-y-2 px-1">
                    <Link href="/auth/login" onClick={() => setMobileMenuOpen(false)} className="text-center py-2 text-on-surface hover:text-primary font-medium">
                      {t('nav.login')}
                    </Link>
                    <Link href="/auth/register" onClick={() => setMobileMenuOpen(false)}>
                      <Button fullWidth>{t('nav.getStarted')}</Button>
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