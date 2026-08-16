'use client';

import { useEffect, useState } from 'react';
import { apiFetch } from '@/lib/api';
import { useRouter } from 'next/navigation';
import { Plus, Trash2 } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Dialog } from '@/components/ui/dialog';
import { Skeleton } from '@/components/ui/skeleton';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface Availability {
  id: string;
  day_of_week: string;
  start_time: string;
  end_time: string;
  is_available: boolean;
}

const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];

async function fetchAvailability(): Promise<Record<string, Availability>> {
  const token = localStorage.getItem('token');
  // GET /availability (no id) is "my own windows", resolved from the token.
  // This used to call /availability/{user.id}, which is wrong twice over:
  // that path wants a Doctor UUID, not a user id, and user ids contain a
  // '#' that truncates the URL into a fragment before it is even sent.
  const res = await apiFetch(`${API_URL}/api/doctors/availability`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  if (!res.ok) {
    const detail = await res.json().catch(() => null);
    throw new Error(
      res.status === 404
        ? 'You don’t have a doctor profile yet, so there are no hours to set.'
        : detail?.detail || `Could not load your availability (HTTP ${res.status}).`
    );
  }

  const data = await res.json();
  const availMap: Record<string, Availability> = {};
  (data.availability || []).forEach((a: Availability) => {
    availMap[a.day_of_week] = a;
  });
  return availMap;
}

export default function DoctorAvailability() {
  const router = useRouter();
  const [availability, setAvailability] = useState<Record<string, Availability>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [selectedDay, setSelectedDay] = useState<string | null>(null);
  const [startTime, setStartTime] = useState('09:00');
  const [endTime, setEndTime] = useState('17:00');

  useEffect(() => {
    const token = localStorage.getItem('token');
    const userData = localStorage.getItem('user');

    if (!token || !userData) {
      router.push('/auth/login');
      return;
    }

    let cancelled = false;
    (async () => {
      try {
        const user = JSON.parse(userData);
        if (user.role !== 'DOCTOR') {
          router.push('/dashboard');
          return;
        }
        const avail = await fetchAvailability();
        if (!cancelled) {
          setAvailability(avail);
          setError('');
        }
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : 'Could not load your availability.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [router]);

  const handleSave = async () => {
    if (!selectedDay) return;

    setSaving(true);
    setError('');
    try {
      const token = localStorage.getItem('token');
      const existing = availability[selectedDay];

      // POST rejects a window that overlaps one already set for that weekday,
      // so a failure here is something the doctor needs to see, not swallow.
      const res = existing
        ? await apiFetch(`${API_URL}/api/doctors/availability/${existing.id}`, {
            method: 'PUT',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({
              start_time: startTime,
              end_time: endTime,
              is_available: true
            })
          })
        : await apiFetch(`${API_URL}/api/doctors/availability`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({
              day_of_week: selectedDay,
              start_time: startTime,
              end_time: endTime,
              is_available: true
            })
          });

      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        setError(detail?.detail || `Could not save those hours (HTTP ${res.status}).`);
        return;
      }

      setSelectedDay(null);
      setAvailability(await fetchAvailability());
    } catch {
      setError('Could not reach the server. Check your connection and try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (day: string) => {
    const avail = availability[day];
    if (!avail) return;

    setSaving(true);
    setError('');
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/doctors/availability/${avail.id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        setError(detail?.detail || `Could not remove those hours (HTTP ${res.status}).`);
        return;
      }
      setAvailability(await fetchAvailability());
    } catch {
      setError('Could not reach the server. Check your connection and try again.');
    } finally {
      setSaving(false);
    }
  };

  const openEdit = (day: string) => {
    const avail = availability[day];
    setSelectedDay(day);
    setStartTime(avail?.start_time?.substring(0, 5) || '09:00');
    setEndTime(avail?.end_time?.substring(0, 5) || '17:00');
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-surface">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Skeleton className="h-9 w-56 mb-lg" />
          <Skeleton className="h-96" />
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-lg">
          <h1 className="text-3xl font-display font-bold text-on-surface">My Availability</h1>
          <Button variant="secondary" size="sm" onClick={() => router.push('/dashboard')}>
            Back to Dashboard
          </Button>
        </div>

        {error && (
          <div className="mb-xl rounded-md border border-alert/40 bg-alert-container px-4 py-2.5 text-sm text-alert">
            {error}
          </div>
        )}

        <Card>
          <h2 className="text-xl font-display font-semibold text-on-surface mb-xs">Set Your Available Times</h2>
          <p className="text-on-surface-variant mb-xl">Click on a day to set your working hours.</p>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-lg">
            {days.map((day) => {
              const dayAvailability = availability[day];
              const isAvailable = dayAvailability?.is_available;

              return (
                <div
                  key={day}
                  className={`p-lg rounded-md border-2 ${
                    isAvailable
                      ? 'border-ok/50 bg-ok-container/60'
                      : 'border-outline bg-surface-card'
                  }`}
                >
                  <div className="flex justify-between items-center mb-sm">
                    <span className="font-semibold text-on-surface text-lg">
                      {day.charAt(0) + day.slice(1).toLowerCase()}
                    </span>
                    {isAvailable && (
                      <button
                        onClick={() => handleDelete(day)}
                        className="inline-flex items-center gap-xs text-alert text-sm hover:underline"
                      >
                        <Trash2 className="w-3.5 h-3.5" aria-hidden="true" />
                        Remove
                      </button>
                    )}
                  </div>

                  {isAvailable && dayAvailability && (
                    <p className="text-sm text-on-surface-variant mb-md">
                      {dayAvailability.start_time?.substring(0, 5)} - {dayAvailability.end_time?.substring(0, 5)}
                    </p>
                  )}

                  <Button
                    onClick={() => openEdit(day)}
                    variant={isAvailable ? "secondary" : "primary"}
                    fullWidth
                    size="sm"
                  >
                    {isAvailable ? 'Edit Time' : (
                      <>
                        <Plus className="w-4 h-4" aria-hidden="true" />
                        Add Availability
                      </>
                    )}
                  </Button>
                </div>
              );
            })}
          </div>
        </Card>

        <Dialog
          open={selectedDay !== null}
          onClose={() => setSelectedDay(null)}
          title={selectedDay ? `Set time for ${selectedDay.charAt(0) + selectedDay.slice(1).toLowerCase()}` : ''}
          footer={
            <div className="grid grid-cols-2 gap-sm w-full">
              <Button
                onClick={handleSave}
                disabled={saving}
                isLoading={saving}
              >
                Save
              </Button>
              <Button
                onClick={() => setSelectedDay(null)}
                variant="secondary"
              >
                Cancel
              </Button>
            </div>
          }
        >
          <div className="space-y-lg">
            <div>
              <label className="text-sm font-semibold text-on-surface block mb-xs">Start Time</label>
              <Input
                type="time"
                value={startTime}
                onChange={(e) => setStartTime(e.target.value)}
              />
            </div>
            <div>
              <label className="text-sm font-semibold text-on-surface block mb-xs">End Time</label>
              <Input
                type="time"
                value={endTime}
                onChange={(e) => setEndTime(e.target.value)}
              />
            </div>
          </div>
        </Dialog>
      </div>
    </div>
  );
}