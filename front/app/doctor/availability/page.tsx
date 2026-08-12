'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Card } from '@/components/card';
import { Button } from '@/components/button';
import { Input } from '@/components/input';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface Availability {
  id: string;
  day_of_week: string;
  start_time: string;
  end_time: string;
  is_available: boolean;
}

const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];

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

    const user = JSON.parse(userData);
    if (user.role !== 'DOCTOR') {
      router.push('/dashboard');
      return;
    }

    fetchAvailability();
  }, [router]);

  const fetchAvailability = async () => {
    try {
      const token = localStorage.getItem('token');
      // GET /availability (no id) is "my own windows", resolved from the token.
      // This used to call /availability/{user.id}, which is wrong twice over:
      // that path wants a Doctor UUID, not a user id, and user ids contain a
      // '#' that truncates the URL into a fragment before it is even sent.
      const res = await fetch(`${API_URL}/api/doctors/availability`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        setError(
          res.status === 404
            ? 'You don’t have a doctor profile yet, so there are no hours to set.'
            : detail?.detail || `Could not load your availability (HTTP ${res.status}).`
        );
        return;
      }

      const data = await res.json();
      const availMap: Record<string, Availability> = {};
      (data.availability || []).forEach((a: Availability) => {
        availMap[a.day_of_week] = a;
      });
      setAvailability(availMap);
      setError('');
    } catch {
      setError('Could not reach the server. Check your connection and reload.');
    } finally {
      setLoading(false);
    }
  };

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
        ? await fetch(`${API_URL}/api/doctors/availability/${existing.id}`, {
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
        : await fetch(`${API_URL}/api/doctors/availability`, {
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
      fetchAvailability();
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
      const res = await fetch(`${API_URL}/api/doctors/availability/${avail.id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        setError(detail?.detail || `Could not remove those hours (HTTP ${res.status}).`);
        return;
      }
      fetchAvailability();
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
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-subtext">Loading...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-text-main">My Availability</h1>
          <Button onClick={() => router.push('/dashboard')}>Back to Dashboard</Button>
        </div>

        {error && (
          <div className="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-2.5 text-sm text-red-800">
            {error}
          </div>
        )}

        <Card className="p-6">
          <h2 className="text-xl font-semibold text-text-main mb-4">Set Your Available Times</h2>
          <p className="text-subtext mb-6">Click on a day to set your working hours.</p>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {days.map((day) => {
              const dayAvailability = availability[day];
              const isAvailable = dayAvailability?.is_available;

              return (
                <div 
                  key={day} 
                  className={`p-4 rounded-lg border-2 ${
                    isAvailable 
                      ? 'border-green-500 bg-green-50' 
                      : 'border-gray-200'
                  }`}
                >
                  <div className="flex justify-between items-center mb-2">
                    <span className="font-medium text-text-main text-lg">
                      {day.charAt(0) + day.slice(1).toLowerCase()}
                    </span>
                    {isAvailable && (
                      <button
                        onClick={() => handleDelete(day)}
                        className="text-red-500 text-sm hover:underline"
                      >
                        Remove
                      </button>
                    )}
                  </div>
                  
                  {isAvailable && dayAvailability && (
                    <p className="text-sm text-subtext mb-3">
                      {dayAvailability.start_time?.substring(0, 5)} - {dayAvailability.end_time?.substring(0, 5)}
                    </p>
                  )}
                  
                  <Button 
                    onClick={() => openEdit(day)}
                    variant={isAvailable ? "secondary" : "primary"}
                    className="w-full"
                  >
                    {isAvailable ? 'Edit Time' : 'Add Availability'}
                  </Button>
                </div>
              );
            })}
          </div>
        </Card>

        {/* Time Selection Modal */}
        {selectedDay && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-lg max-w-md w-full p-6">
              <h3 className="text-xl font-bold text-text-main mb-4">
                Set Time for {selectedDay.charAt(0) + selectedDay.slice(1).toLowerCase()}
              </h3>
              
              <div className="space-y-4 mb-6">
                <div>
                  <label className="text-sm font-medium text-gray-700">Start Time</label>
                  <Input
                    type="time"
                    value={startTime}
                    onChange={(e) => setStartTime(e.target.value)}
                  />
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">End Time</label>
                  <Input
                    type="time"
                    value={endTime}
                    onChange={(e) => setEndTime(e.target.value)}
                  />
                </div>
              </div>

              <div className="flex gap-2">
                <Button 
                  onClick={handleSave} 
                  disabled={saving}
                  className="flex-1"
                >
                  {saving ? 'Saving...' : 'Save'}
                </Button>
                <Button 
                  onClick={() => setSelectedDay(null)} 
                  variant="secondary"
                  className="flex-1"
                >
                  Cancel
                </Button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}