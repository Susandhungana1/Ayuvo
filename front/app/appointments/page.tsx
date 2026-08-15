'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { CalendarDays, Plus, CalendarPlus, CheckCircle2, Download, XCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { StatusChip } from '@/components/ui/status-chip';
import { EmptyState } from '@/components/ui/empty-state';
import { Dialog } from '@/components/ui/dialog';
import { Skeleton } from '@/components/ui/skeleton';
import { downloadIcs } from '@/lib/ics';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface Appointment {
  id: string;
  title: string;
  description?: string;
  doctor_id?: string;
  doctor_name?: string;
  hospital?: string;
  appointment_date: string;
  duration_minutes: number;
  status: string;
  reason?: string;
}

interface Doctor {
  id: string;
  nmid: string;
  name: string;
  degree: string;
  specialty: string;
}

const SELECT_CLASS =
  'flex h-11 w-full rounded-sm border border-outline bg-surface-card px-3.5 text-base text-on-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring';

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
  const res = await fetch(`${API_URL}/api/appointments`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  if (res.ok) {
    const data = await res.json();
    return data.appointments || [];
  }
  return [];
}

async function fetchDoctors(): Promise<Doctor[]> {
  const token = localStorage.getItem('token');
  const res = await fetch(`${API_URL}/api/doctors/doctors`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  if (res.ok) {
    const data = await res.json();
    return data.doctors || data || [];
  }
  return [];
}

const EMPTY_FORM = {
  title: '',
  description: '',
  doctor_id: '',
  doctor_name: '',
  hospital: '',
  appointment_date: '',
  duration_minutes: '30',
  reason: ''
};

export default function Appointments() {
  const router = useRouter();
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [doctors, setDoctors] = useState<Doctor[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState(EMPTY_FORM);
  const [error, setError] = useState('');
  const [showSuccess, setShowSuccess] = useState(false);
  const [successAppointment, setSuccessAppointment] = useState<Appointment | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const [appList, docList] = await Promise.all([fetchAppointments(), fetchDoctors()]);
        if (!cancelled) {
          setAppointments(appList);
          setDoctors(docList);
        }
      } catch (err) {
        console.error(err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    const selectedDoctor = doctors.find(d => d.id === formData.doctor_id);
    const submitData = {
      ...formData,
      doctor_name: selectedDoctor?.name || formData.doctor_name,
      appointment_date: formData.appointment_date + ':00'
    };

    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/appointments`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(submitData)
      });

      if (!res.ok) {
        const data = await res.json();
        let errorMsg = 'Failed to create appointment';
        if (typeof data.detail === 'string') {
          errorMsg = data.detail;
        } else if (Array.isArray(data.detail)) {
          errorMsg = data.detail[0]?.message || data.detail[0]?.msg || JSON.stringify(data.detail);
        } else if (data.detail?.message) {
          errorMsg = data.detail.message;
        }
        throw new Error(errorMsg);
      }

      const data = await res.json();
      setSuccessAppointment(data);
      setShowSuccess(true);
      setShowForm(false);
      setAppointments(await fetchAppointments());
      setFormData(EMPTY_FORM);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to create appointment');
    }
  };

  const handleAddToCalendar = (apt: Appointment) => {
    const parts = [
      apt.doctor_name ? `Doctor: Dr. ${apt.doctor_name}` : '',
      apt.hospital ? `Location: ${apt.hospital}` : '',
      apt.reason ? `Reason: ${apt.reason}` : '',
      apt.description || '',
    ].filter(Boolean);
    downloadIcs({
      id: apt.id,
      title: apt.title,
      description: parts.join('\n'),
      location: apt.hospital,
      start: apt.appointment_date,
      durationMinutes: apt.duration_minutes || 30,
    });
  };

  const handleCancel = async (id: string) => {
    if (!confirm('Are you sure you want to cancel this appointment?')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/appointments/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        setAppointments(appointments.filter(a => a.id !== id));
      }
    } catch (err) {
      console.error(err);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-surface">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Skeleton className="h-9 w-56 mb-lg" />
          <Skeleton className="h-10 w-44 mb-lg" />
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
          <h1 className="text-3xl font-display font-bold text-on-surface">Appointments</h1>
        </div>

        <div className="mb-lg">
          <Button onClick={() => setShowForm(!showForm)}>
            {showForm ? 'Cancel' : (
              <>
                <Plus className="w-4 h-4" aria-hidden="true" />
                Book Appointment
              </>
            )}
          </Button>
        </div>

        {showForm && (
          <Card className="mb-lg">
            <form onSubmit={handleSubmit} className="space-y-lg">
              <Input
                label="Title"
                name="title"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                placeholder="e.g., Annual Checkup"
                required
              />
              <div className="flex flex-col gap-sm w-full">
                <label className="text-sm font-semibold text-on-surface">Select Doctor</label>
                <select
                  value={formData.doctor_id}
                  onChange={(e) => setFormData({ ...formData, doctor_id: e.target.value })}
                  className={SELECT_CLASS}
                >
                  <option value="">Select a doctor (optional)</option>
                  {doctors.map((doc) => (
                    <option key={doc.id} value={doc.id}>
                      Dr. {doc.name} - {doc.specialty}
                    </option>
                  ))}
                </select>
              </div>
              <Input
                label="Hospital"
                name="hospital"
                value={formData.hospital}
                onChange={(e) => setFormData({ ...formData, hospital: e.target.value })}
                placeholder="Hospital name"
              />
              <Input
                label="Date & Time"
                name="appointment_date"
                type="datetime-local"
                value={formData.appointment_date}
                onChange={(e) => setFormData({ ...formData, appointment_date: e.target.value })}
                required
              />
              <Input
                label="Duration (minutes)"
                name="duration_minutes"
                type="number"
                value={formData.duration_minutes}
                onChange={(e) => setFormData({ ...formData, duration_minutes: e.target.value })}
              />
              <div className="flex flex-col gap-sm w-full">
                <label className="text-sm font-semibold text-on-surface">Reason</label>
                <textarea
                  value={formData.reason}
                  onChange={(e) => setFormData({ ...formData, reason: e.target.value })}
                  placeholder="Reason for visit..."
                  className="flex w-full rounded-sm border border-outline bg-surface-card px-3.5 py-2 text-base text-on-surface placeholder:text-on-surface-variant/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring"
                  rows={3}
                />
              </div>
              {error && <p className="text-alert text-sm" role="alert">{error}</p>}
              <Button type="submit">Book Appointment</Button>
            </form>
          </Card>
        )}

        {appointments.length === 0 ? (
          <Card>
            <EmptyState
              icon={CalendarDays}
              title="No appointments scheduled"
              description="Book a checkup or consultation with a doctor to see it here."
              action={<Button onClick={() => setShowForm(true)}>Book Your First Appointment</Button>}
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
                  {apt.doctor_name && (
                    <p className="text-on-surface-variant text-sm mb-xs">Dr. {apt.doctor_name}</p>
                  )}
                  {apt.hospital && (
                    <p className="text-on-surface-variant text-sm mb-xs">{apt.hospital}</p>
                  )}
                  <p className="text-on-surface-variant text-sm mb-md">
                    {new Date(apt.appointment_date).toLocaleString()}
                  </p>
                  {apt.reason && (
                    <p className="text-on-surface-variant text-sm mb-lg">{apt.reason}</p>
                  )}
                  <div className="flex items-center gap-lg mt-auto pt-md">
                    <button
                      onClick={() => handleAddToCalendar(apt)}
                      className="inline-flex items-center gap-xs text-primary text-sm font-semibold hover:underline"
                    >
                      <Download className="w-4 h-4" aria-hidden="true" />
                      Add to Calendar
                    </button>
                    <button
                      onClick={() => handleCancel(apt.id)}
                      className="inline-flex items-center gap-xs text-alert text-sm font-medium hover:underline"
                    >
                      <XCircle className="w-4 h-4" aria-hidden="true" />
                      Cancel
                    </button>
                  </div>
                </Card>
              );
            })}
          </div>
        )}
      </div>

      <Dialog
        open={showSuccess && !!successAppointment}
        onClose={() => setShowSuccess(false)}
        title="Appointment Booked!"
        footer={
          <div className="grid grid-cols-2 gap-sm w-full">
            <Button variant="secondary" onClick={() => successAppointment && handleAddToCalendar(successAppointment)}>
              Add to Calendar
            </Button>
            <Button onClick={() => setShowSuccess(false)}>Done</Button>
          </div>
        }
      >
        {successAppointment && (
          <div>
            <div className="flex items-start gap-md mb-lg">
              <div className="w-10 h-10 bg-ok-container text-ok rounded-full flex items-center justify-center shrink-0">
                <CheckCircle2 className="w-5 h-5" aria-hidden="true" />
              </div>
              <p className="text-on-surface-variant">
                Your appointment has been successfully scheduled.
              </p>
            </div>
            <div className="bg-outline/10 rounded-md p-lg mb-lg">
              <p className="font-semibold text-on-surface">{successAppointment.title}</p>
              {successAppointment.doctor_name && (
                <p className="text-sm text-on-surface-variant">Dr. {successAppointment.doctor_name}</p>
              )}
              <p className="text-sm text-on-surface-variant">
                {new Date(successAppointment.appointment_date).toLocaleString()}
              </p>
              <p className="text-xs text-on-surface-variant mt-sm">ID: {successAppointment.id}</p>
            </div>
            <p className="text-xs text-on-surface-variant">
              <CalendarPlus className="inline w-3.5 h-3.5 mr-xs" aria-hidden="true" />
              Save it to your calendar so you get a reminder.
            </p>
          </div>
        )}
      </Dialog>
    </div>
  );
}