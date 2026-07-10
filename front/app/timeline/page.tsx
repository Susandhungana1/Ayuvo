'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Card } from '@/components/card';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface TimelineEvent {
  type: string;
  id: string;
  title: string;
  description: string | null;
  date: string;
}

export default function Timeline() {
  const router = useRouter();
  const [events, setEvents] = useState<TimelineEvent[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) { router.push('/auth/login'); return; }
    fetchTimeline();
  }, [router]);

  const fetchTimeline = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/timeline?limit=100`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setEvents(data.events || []);
      }
    } catch (err) { console.error(err);
    } finally { setLoading(false); }
  };

  const getTypeIcon = (type: string) => {
    switch (type) {
      case 'report': return '📄';
      case 'medicine': return '💊';
      case 'appointment': return '📅';
      case 'vital': return '❤️';
      default: return '📌';
    }
  };

  const getTypeColor = (type: string) => {
    switch (type) {
      case 'report': return 'border-blue-400';
      case 'medicine': return 'border-green-400';
      case 'appointment': return 'border-purple-400';
      case 'vital': return 'border-red-400';
      default: return 'border-gray-400';
    }
  };

  if (loading) {
    return <div className="min-h-screen bg-background flex items-center justify-center"><p className="text-subtext">Loading...</p></div>;
  }

  // Group by date
  const grouped: Record<string, TimelineEvent[]> = {};
  events.forEach(e => {
    const dateKey = new Date(e.date).toLocaleDateString();
    if (!grouped[dateKey]) grouped[dateKey] = [];
    grouped[dateKey].push(e);
  });

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-6">
          <h1 className="text-2xl sm:text-3xl font-bold text-text-main">Health Timeline</h1>
          <p className="text-sm sm:text-base text-subtext mt-1">A chronological view of all your health events</p>
        </div>

        {events.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext">No activity yet. Start by uploading reports, adding medicines, or tracking vitals.</p>
          </Card>
        ) : (
          <div className="relative">
            <div className="absolute left-[19px] sm:left-[23px] top-0 bottom-0 w-0.5 bg-gray-200" />
            {Object.entries(grouped).map(([dateKey, dateEvents]) => (
              <div key={dateKey} className="mb-6 sm:mb-8">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-9 h-9 rounded-full bg-primary flex items-center justify-center flex-shrink-0">
                    <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                  <div>
                    <h2 className="text-sm font-bold text-text-main">{dateKey}</h2>
                    <span className="text-xs text-subtext">{dateEvents.length} event{dateEvents.length !== 1 ? 's' : ''}</span>
                  </div>
                </div>
                <div className="ml-4 sm:ml-6 space-y-4">
                  {dateEvents.map(e => (
                    <div key={`${e.type}-${e.id}`} className="relative pl-8 sm:pl-10">
                      <div className={`absolute left-0 top-1 w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-white border-[3px] flex items-center justify-center text-sm shadow-sm ${getTypeColor(e.type)}`}>
                        {getTypeIcon(e.type)}
                      </div>
                      <Card className={`p-3 sm:p-4 border-l-4 ${getTypeColor(e.type)}`}>
                        <div className="flex flex-col sm:flex-row sm:items-center gap-0 sm:gap-2 mb-1">
                          <span className="text-xs font-medium uppercase tracking-wider text-subtext">{e.type}</span>
                          <span className="text-xs text-subtext">{new Date(e.date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                        </div>
                        <h3 className="font-semibold text-text-main text-sm sm:text-base">{e.title}</h3>
                        {e.description && <p className="text-xs sm:text-sm text-subtext mt-1 line-clamp-3">{e.description}</p>}
                      </Card>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
