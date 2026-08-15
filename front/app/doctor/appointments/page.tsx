'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { CalendarClock } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { StatusChip } from '@/components/ui/status-chip';
import { EmptyState } from '@/components/ui/empty-state';
import { Skeleton } from '@/components/ui/skeleton';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface Appointment {
  id: string;
  title: string;
  description?: string;
  doctor_id?: string;
  doctor_name?: string;
  appointment_date: string;
  duration_minutes: number;
  status: string;
  reason?: string;
}

function statusChip(status: string) {
  switch (status) {
    case 'CONFIRMED': return { level: 'ok' as const, label: 'Confirmed' };
    case 'PENDING': return { level: 'caution' as const, label: 'Pending' };
    case 'COMPLETED': return { level: 'ok' as const, label: 'Completed' };
    default: return { level: 'alert' as const, label: status.replace(/_/g, ' ').toLowerCase() };
  }
}

async function fetchAppointments(): Promise<Appointment[]> {
  const token = localStorage.getItem('token');
  const res = await fetch(`${API_URL}/api/appointments/doctor/my-appointments`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  if (res.ok) {
    const data = await res.json();
    return data.appointments || [];
  }
  return [];
}

export default function DoctorAppointments() {
  const router = useRouter();
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

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
        const list = await fetchAppointments();
        if (!cancelled) setAppointments(list);
      } catch (err) {
        console.error(err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [router]);

  const updateStatus = async (id: string, status: string) => {
    setError('');
    try {
      const token = localStorage.getItem('token');
      // Two things were wrong here. The status goes in the query string — the
      // route declares it as a bare enum, so FastAPI reads it as a query
      // parameter and a JSON body was a 422. And /status authorises against
      // Appointment.user_id, the *patient* who booked, so a doctor calling it
      // always got a 404; /status/by-doctor is the doctor-of-record route.
      const res = await fetch(
        `${API_URL}/api/appointments/${id}/status/by-doctor?status=${encodeURIComponent(status)}`,
        { method: 'PATCH', headers: { 'Authorization': `Bearer ${token}` } }
      );

      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        setError(detail?.detail || `Could not update this appointment (HTTP ${res.status}).`);
        return;
      }
      setAppointments(appointments.map(a =>
        a.id === id ? { ...a, status } : a
      ));
    } catch {
      setError('Could not reach the server. Check your connection and try again.');
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-surface">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Skeleton className="h-9 w-64 mb-lg" />
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-xl">
            {[0, 1, 2].map(i => (
              <Skeleton key={i} className="h-48" />
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-lg">
          <h1 className="text-3xl font-display font-bold text-on-surface">Patient Appointments</h1>
          <Button variant="secondary" size="sm" onClick={() => router.push('/dashboard')}>
            Back to Dashboard
          </Button>
        </div>

        {error && (
          <div className="mb-xl rounded-md border border-alert/40 bg-alert-container px-4 py-2.5 text-sm text-alert">
            {error}
          </div>
        )}

        {appointments.length === 0 ? (
          <Card>
            <EmptyState
              icon={CalendarClock}
              title="No appointments yet"
              description="When patients book a slot with you, it will appear here for review."
            />
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-xl">
            {appointments.map((apt) => {
              const chip = statusChip(apt.status);
              return (
                <Card key={apt.id} className="flex flex-col">
                  <div className="flex justify-between items-start gap-sm mb-md">
                    <h3 className="text-lg font-display font-semibold text-on-surface">{apt.title}</h3>
                    <StatusChip level={chip.level} label={chip.label} className="shrink-0" />
                  </div>

                  <p className="text-on-surface-variant text-sm mb-sm">
                    {new Date(apt.appointment_date).toLocaleString()}
                  </p>

                  <p className="text-on-surface-variant text-sm mb-sm">
                    {apt.duration_minutes} minutes
                  </p>

                  {apt.reason && (
                    <p className="text-on-surface-variant text-sm mb-lg">{apt.reason}</p>
                  )}

                  <div className="flex gap-sm mt-auto pt-lg">
                    {apt.status === 'PENDING' && (
                      <>
                        <Button onClick={() => updateStatus(apt.id, 'CONFIRMED')}>
                          Accept
                        </Button>
                        <Button onClick={() => updateStatus(apt.id, 'CANCELLED')} variant="secondary">
                          Reject
                        </Button>
                      </>
                    )}
                    {apt.status === 'CONFIRMED' && (
                      <Button onClick={() => updateStatus(apt.id, 'COMPLETED')}>
                        Mark Completed
                      </Button>
                    )}
                  </div>
                </Card>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}