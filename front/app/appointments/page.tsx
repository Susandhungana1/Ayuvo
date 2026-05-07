'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Input } from '@/components/input';

const API_URL = 'http://127.0.0.1:3001';

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

export default function Appointments() {
  const router = useRouter();
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [doctors, setDoctors] = useState<Doctor[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    doctor_id: '',
    doctor_name: '',
    hospital: '',
    appointment_date: '',
    duration_minutes: '30',
    reason: ''
  });
  const [error, setError] = useState('');
  const [showSuccess, setShowSuccess] = useState(false);
  const [successAppointment, setSuccessAppointment] = useState<Appointment | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    fetchData();
  }, [router]);

  const fetchData = async () => {
    try {
      const token = localStorage.getItem('token');
      const [appRes, docRes] = await Promise.all([
        fetch(`${API_URL}/api/appointments`, {
          headers: { 'Authorization': `Bearer ${token}` }
        }),
        fetch(`${API_URL}/api/doctors/doctors`, {
          headers: { 'Authorization': `Bearer ${token}` }
        })
      ]);

      if (appRes.ok) {
        const data = await appRes.json();
        setAppointments(data.appointments || []);
      }

      if (docRes.ok) {
        const data = await docRes.json();
        setDoctors(data.doctors || data || []);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    const selectedDoctor = doctors.find(d => d.id === formData.doctor_id);
    const submitData = {
      ...formData,
      doctor_name: selectedDoctor?.name || formData.doctor_name,
      appointment_date: new Date(formData.appointment_date).toISOString()
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
      fetchData();
      setFormData({
        title: '',
        description: '',
        doctor_id: '',
        doctor_name: '',
        hospital: '',
        appointment_date: '',
        duration_minutes: '30',
        reason: ''
      });
    } catch (err: any) {
      setError(err.message);
    }
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
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-subtext">Loading...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-text-main">Appointments</h1>
        </div>

        <div className="mb-6">
          <Button onClick={() => setShowForm(!showForm)}>
            {showForm ? 'Cancel' : '+ Book Appointment'}
          </Button>
        </div>

        {showForm && (
          <Card className="p-6 mb-8">
            <form onSubmit={handleSubmit} className="space-y-4">
              <Input
                label="Title"
                name="title"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                placeholder="e.g., Annual Checkup"
                required
              />
              <div className="flex flex-col gap-1.5 w-full">
                <label className="text-sm font-medium text-gray-700">Select Doctor</label>
                <select
                  value={formData.doctor_id}
                  onChange={(e) => setFormData({ ...formData, doctor_id: e.target.value })}
                  className="flex h-10 w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
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
              <div className="flex flex-col gap-1.5 w-full">
                <label className="text-sm font-medium text-gray-700">Reason</label>
                <textarea
                  value={formData.reason}
                  onChange={(e) => setFormData({ ...formData, reason: e.target.value })}
                  placeholder="Reason for visit..."
                  className="flex w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
                  rows={3}
                />
              </div>
              {error && <p className="text-red-500 text-sm">{error}</p>}
              <Button type="submit">Book Appointment</Button>
            </form>
          </Card>
        )}

        {appointments.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext mb-4">No appointments scheduled</p>
            <Button onClick={() => setShowForm(true)}>Book Your First Appointment</Button>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {appointments.map((apt) => (
              <Card key={apt.id} className="p-6">
                <div className="flex justify-between items-start mb-2">
                  <h3 className="text-lg font-semibold text-text-main">{apt.title}</h3>
                  <span className={`px-2 py-1 text-xs rounded-full ${
                    apt.status === 'CONFIRMED' ? 'bg-green-100 text-green-700' :
                    apt.status === 'PENDING' ? 'bg-yellow-100 text-yellow-700' :
                    'bg-gray-100 text-gray-700'
                  }`}>
                    {apt.status}
                  </span>
                </div>
                {apt.doctor_name && (
                  <p className="text-subtext text-sm mb-1">Dr. {apt.doctor_name}</p>
                )}
                {apt.hospital && (
                  <p className="text-subtext text-sm mb-1">{apt.hospital}</p>
                )}
                <p className="text-subtext text-sm mb-2">
                  {new Date(apt.appointment_date).toLocaleString()}
                </p>
                {apt.reason && (
                  <p className="text-subtext text-sm mb-4">{apt.reason}</p>
                )}
                <button
                  onClick={() => handleCancel(apt.id)}
                  className="text-red-500 text-sm hover:underline"
                >
                  Cancel Appointment
                </button>
              </Card>
            ))}
          </div>
        )}
      </div>

      {showSuccess && successAppointment && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-md w-full p-8 text-center">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h2 className="text-2xl font-bold text-text-main mb-2">Appointment Booked!</h2>
            <p className="text-subtext mb-4">Your appointment has been successfully scheduled.</p>
            <div className="bg-gray-50 rounded-lg p-4 text-left mb-6">
              <p className="font-medium text-text-main">{successAppointment.title}</p>
              {successAppointment.doctor_name && (
                <p className="text-sm text-subtext">Dr. {successAppointment.doctor_name}</p>
              )}
              <p className="text-sm text-subtext">
                {new Date(successAppointment.appointment_date).toLocaleString()}
              </p>
              <p className="text-xs text-gray-500 mt-2">ID: {successAppointment.id}</p>
            </div>
            <Button onClick={() => setShowSuccess(false)}>Done</Button>
          </div>
        </div>
      )}
    </div>
  );
}