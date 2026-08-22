'use client';

import { Button } from '@/components/ui/button';
import { Loader2 } from 'lucide-react';

interface LoadMoreProps {
  offset: number;
  total: number;
  limit: number;
  loading: boolean;
  onLoadMore: () => void;
}

export function LoadMore({ offset, total, loading, onLoadMore }: LoadMoreProps) {
  const remaining = total - offset;
  if (remaining <= 0) return null;

  return (
    <div className="flex justify-center py-lg">
      <Button
        variant="secondary"
        onClick={onLoadMore}
        disabled={loading}
        className="min-w-[140px]"
      >
        {loading ? (
          <Loader2 className="w-4 h-4 animate-spin" aria-hidden="true" />
        ) : (
          `Load more (${remaining} remaining)`
        )}
      </Button>
    </div>
  );
}
