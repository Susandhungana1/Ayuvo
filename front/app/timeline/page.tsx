'use client';

import { useEffect, useState } from 'react';
import { apiFetch, API_URL } from '@/lib/api';
import { useRouter } from 'next/navigation';
import { FileText, Pill, CalendarDays, Activity, Pin, History } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/ui/empty-state';
import { formatServerDate, formatServerTimeOfDay } from '@/lib/datetime';



interface TimelineEvent {
  type: string;
  id: string;
  title: string;
  description: string | null;
  date: string;
}

const TYPE_ICONS: Record<string, typeof FileText> = {
  report: FileText,
  medicine: Pill,
  appointment: CalendarDays,
  vital: Activity,
};

const TYPE_COLORS: Record<string, string> = {
  report: 'border-series-1 text-series-1',
  medicine: 'border-series-2 text-series-2',
  appointment: 'border-series-3 text-series-3',
  vital: 'border-series-4 text-series-4',
};

export default function Timeline() {
  const router = useRouter();
  const [events, setEvents] = useState<TimelineEvent[] | null>(null);

  const fetchTimeline = async (): Promise<TimelineEvent[]> => {
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/timeline?limit=100`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        return data.events || [];
      }
    } catch (err) { console.error(err); }
    return [];
  };

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) { router.push('/auth/login'); return; }
    let cancelled = false;
    (async () => {
      try {
        const list = await fetchTimeline();
        if (!cancelled) setEvents(list);
      } catch (err) { console.error(err); }
    })();
    return () => { cancelled = true; };
  }, [router]);

  const loading = events === null;

  if (loading) {
    return (
      <div className="min-h-screen bg-surface">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Skeleton className="h-8 w-56 mb-8" />
          <div className="space-y-4">
            {[1, 2, 3].map((i) => <Skeleton key={i} className="h-20" />)}
          </div>
        </div>
      </div>
    );
  }

  // Group by date
  const grouped: Record<string, TimelineEvent[]> = {};
  events.forEach(e => {
    const dateKey = formatServerDate(e.date);
    if (!grouped[dateKey]) grouped[dateKey] = [];
    grouped[dateKey].push(e);
  });

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-6">
          <h1 className="text-2xl sm:text-3xl font-display font-bold text-on-surface">Health Timeline</h1>
          <p className="text-sm sm:text-base text-on-surface-variant mt-1">A chronological view of all your health events</p>
        </div>

        {events.length === 0 ? (
          <Card className="p-lg">
            <EmptyState
              icon={History}
              title="No activity yet"
              description="Start by uploading reports, adding medicines, or tracking vitals — it will all land here."
            />
          </Card>
        ) : (
          <div className="relative">
            <div className="absolute left-[19px] sm:left-[23px] top-0 bottom-0 w-0.5 bg-outline" />
            {Object.entries(grouped).map(([dateKey, dateEvents]) => (
              <div key={dateKey} className="mb-6 sm:mb-8">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-9 h-9 rounded-full bg-primary flex items-center justify-center flex-shrink-0">
                    <CalendarDays className="w-4 h-4 text-on-primary" />
                  </div>
                  <div>
                    <h2 className="text-sm font-display font-bold text-on-surface">{dateKey}</h2>
                    <span className="text-xs text-on-surface-variant">{dateEvents.length} event{dateEvents.length !== 1 ? 's' : ''}</span>
                  </div>
                </div>
                <div className="ml-4 sm:ml-6 space-y-4">
                  {dateEvents.map(e => {
                    const Icon = TYPE_ICONS[e.type] ?? Pin;
                    const color = TYPE_COLORS[e.type] ?? 'border-outline text-on-surface-variant';
                    return (
                      <div key={`${e.type}-${e.id}`} className="relative pl-8 sm:pl-10">
                        <div className={`absolute left-0 top-1 w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-surface-card border-[3px] flex items-center justify-center shadow-sm ${color}`}>
                          <Icon className="w-3.5 h-3.5" />
                        </div>
                        <Card className="p-lg border-l-2 rounded-sm">
                          <div className="flex flex-col sm:flex-row sm:items-center gap-0 sm:gap-2 mb-1">
                            <span className="text-xs font-medium uppercase tracking-wider text-on-surface-variant">{e.type}</span>
                            <span className="text-xs text-on-surface-variant tabular-nums">{formatServerTimeOfDay(e.date)}</span>
                          </div>
                          <h3 className="font-display font-semibold text-on-surface text-sm sm:text-base">{e.title}</h3>
                          {e.description && <p className="text-xs sm:text-sm text-on-surface-variant mt-1 line-clamp-3">{e.description}</p>}
                        </Card>
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}