'use client';

import { useEffect, useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { Card } from '@/components/card';
import { Input } from '@/components/input';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface SearchResult {
  type: string;
  id: string;
  title: string;
  snippet: string | null;
  date: string | null;
}

function SearchContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const query = searchParams.get('q') || '';
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [searchInput, setSearchInput] = useState(query);

  useEffect(() => {
    if (query) {
      setSearchInput(query);
      doSearch(query);
    }
  }, [query]);

  const doSearch = async (q: string) => {
    if (!q.trim()) return;
    setLoading(true);
    try {
      const token = localStorage.getItem('token');
      if (!token) { router.push('/auth/login'); return; }
      const res = await fetch(`${API_URL}/api/search?q=${encodeURIComponent(q)}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setResults(data.results || []);
      }
    } catch (err) { console.error(err);
    } finally { setLoading(false); }
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchInput.trim()) {
      router.push(`/search?q=${encodeURIComponent(searchInput.trim())}`);
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

  const getTypeBadge = (type: string) => {
    switch (type) {
      case 'report': return 'bg-blue-100 text-blue-700';
      case 'medicine': return 'bg-green-100 text-green-700';
      case 'document': return 'bg-purple-100 text-purple-700';
      default: return 'bg-gray-100 text-gray-700';
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-text-main mb-4 sm:mb-6">Search</h1>

        <form onSubmit={handleSearch} className="mb-6 sm:mb-8">
          <div className="flex gap-2">
            <div className="flex-1 min-w-0">
              <input
                type="text"
                value={searchInput}
                onChange={e => setSearchInput(e.target.value)}
                placeholder="Search reports, medicines, documents..."
                className="flex h-10 w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm"
                autoFocus
              />
            </div>
            <button type="submit" className="bg-primary text-white px-4 sm:px-6 py-2 rounded-md text-sm font-medium hover:bg-blue-700 whitespace-nowrap">
              Search
            </button>
          </div>
        </form>

        {loading && <p className="text-subtext">Searching...</p>}

        {!loading && query && results.length === 0 && (
          <Card className="p-8 text-center">
            <p className="text-subtext">No results found for "{query}"</p>
          </Card>
        )}

        {results.length > 0 && (
          <div>
            <p className="text-sm text-subtext mb-4">Found {results.length} result{results.length !== 1 ? 's' : ''} for &ldquo;{query}&rdquo;</p>
            <div className="space-y-3">
              {results.map(r => (
                <Link key={`${r.type}-${r.id}`} href={getResultLink(r)}>
                  <Card className="p-3 sm:p-4 hover:shadow-md transition-shadow cursor-pointer">
                    <div className="flex items-center gap-2 mb-1">
                      <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${getTypeBadge(r.type)}`}>
                        {r.type}
                      </span>
                      {r.date && <span className="text-xs text-subtext">{new Date(r.date).toLocaleDateString()}</span>}
                    </div>
                    <h3 className="font-semibold text-text-main text-sm sm:text-base truncate">{r.title}</h3>
                    {r.snippet && <p className="text-xs sm:text-sm text-subtext mt-1 line-clamp-2">{r.snippet}</p>}
                  </Card>
                </Link>
              ))}
            </div>
          </div>
        )}

        {!query && (
          <Card className="p-8 text-center">
            <p className="text-subtext">Enter a search term to find reports, medicines, and documents</p>
          </Card>
        )}
      </div>
    </div>
  );
}

export default function SearchPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-background flex items-center justify-center"><p className="text-subtext">Loading...</p></div>}>
      <SearchContent />
    </Suspense>
  );
}
