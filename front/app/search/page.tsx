'use client';

import { useEffect, useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { Search as SearchIcon } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { EmptyState } from '@/components/ui/empty-state';
import { formatServerDate } from '@/lib/datetime';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface SearchResult {
  type: string;
  id: string;
  title: string;
  snippet: string | null;
  date: string | null;
}

const TYPE_BADGE: Record<string, string> = {
  report: 'bg-series-1/10 text-series-1',
  medicine: 'bg-series-4/10 text-series-4',
  document: 'bg-series-2/10 text-series-2',
};

async function doSearch(q: string): Promise<SearchResult[]> {
  const token = localStorage.getItem('token');
  if (!token) return [];
  const res = await fetch(`${API_URL}/api/search?q=${encodeURIComponent(q)}`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  if (!res.ok) return [];
  const data = await res.json();
  return data.results || [];
}

function SearchContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const query = searchParams.get('q') || '';
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loadedFor, setLoadedFor] = useState('');
  // Searching while the query in the URL differs from the one results belong to.
  const searching = !!query && loadedFor !== query;

  useEffect(() => {
    if (!query) return;
    let cancelled = false;
    (async () => {
      try {
        const found = await doSearch(query);
        if (!cancelled) {
          setResults(found);
          setLoadedFor(query);
        }
      } catch (err) {
        console.error(err);
        if (!cancelled) {
          setResults([]);
          setLoadedFor(query);
        }
      }
    })();
    return () => { cancelled = true; };
  }, [query]);

  const handleSearch = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const q = new FormData(e.currentTarget).get('search');
    if (typeof q === 'string' && q.trim()) {
      router.push(`/search?q=${encodeURIComponent(q.trim())}`);
    }
  };

  const getResultLink = (r: SearchResult) => {
    switch (r.type) {
      case 'report': return `/reports?highlight=${r.id}`;
      case 'medicine': return `/medicines`;
      case 'document': return `/documents`;
      default: return '#';
    }
  };

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        <h1 className="text-2xl sm:text-3xl font-display font-bold text-on-surface mb-4 sm:mb-6">Search</h1>

        <form onSubmit={handleSearch} className="mb-6 sm:mb-8">
          <div className="flex gap-sm">
            <div className="flex-1 min-w-0">
              <Input
                key={query}
                type="text"
                name="search"
                defaultValue={query}
                placeholder="Search reports, medicines, documents..."
                aria-label="Search terms"
                autoFocus
              />
            </div>
            <Button type="submit" className="shrink-0">
              <SearchIcon className="w-4 h-4" aria-hidden="true" />
              Search
            </Button>
          </div>
        </form>

        {searching && <p className="text-on-surface-variant">Searching…</p>}

        {!searching && query && results.length === 0 && (
          <Card>
            <EmptyState
              icon={SearchIcon}
              title={`No results found for “${query}”`}
              description="Try a different term, or check the spelling."
            />
          </Card>
        )}

        {!searching && results.length > 0 && (
          <div>
            <p className="text-sm text-on-surface-variant mb-lg">
              Found {results.length} result{results.length !== 1 ? 's' : ''} for &ldquo;{query}&rdquo;
            </p>
            <div className="space-y-sm">
              {results.map(r => (
                <Link key={`${r.type}-${r.id}`} href={getResultLink(r)}>
                  <Card className="p-md hover:border-primary/50 hover:shadow-float transition-all cursor-pointer">
                    <div className="flex items-center gap-sm mb-xs">
                      <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${TYPE_BADGE[r.type] || 'bg-outline/20 text-on-surface-variant'}`}>
                        {r.type}
                      </span>
                      {r.date && <span className="text-xs text-on-surface-variant">{formatServerDate(r.date)}</span>}
                    </div>
                    <h3 className="font-semibold text-on-surface text-sm sm:text-base truncate">{r.title}</h3>
                    {r.snippet && <p className="text-xs sm:text-sm text-on-surface-variant mt-xs line-clamp-2">{r.snippet}</p>}
                  </Card>
                </Link>
              ))}
            </div>
          </div>
        )}

        {!query && !searching && (
          <Card>
            <EmptyState
              icon={SearchIcon}
              title="Search your health records"
              description="Find reports, medicines, and documents by entering a search term above."
            />
          </Card>
        )}
      </div>
    </div>
  );
}

export default function SearchPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-surface flex items-center justify-center"><p className="text-on-surface-variant">Loading…</p></div>}>
      <SearchContent />
    </Suspense>
  );
}