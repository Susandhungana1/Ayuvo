import Link from 'next/link';
import { CalendarClock } from 'lucide-react';
import { EmptyState } from '@/components/ui/empty-state';

export function ComingSoon() {
  return (
    <div className="min-h-[60vh] flex flex-col items-center justify-center px-4 py-16">
      <EmptyState
        icon={CalendarClock}
        title="Coming soon"
        description="Appointments are on the way. We are preparing the booking experience — check back soon."
        action={
          <Link
            href="/"
            className="inline-flex items-center rounded-[var(--radius-sm)] bg-[var(--color-primary)] text-white px-4 py-2 text-sm font-medium hover:bg-[var(--color-primary-hover)] transition-colors"
          >
            Back to home
          </Link>
        }
      />
    </div>
  );
}