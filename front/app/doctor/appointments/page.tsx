'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Card } from '@/components/card';
import { Button } from '@/components/button';

const API_URL = 'http://127.0.0.1:3001';

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

export default function DoctorAppointments() {
  const router = useRouter();
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [loading, setLoading] = useState(true);

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

    fetchAppointments();
  }, [router]);

  const fetchAppointments = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/appointments/doctor/my-appointments`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (res.ok) {
        const data = await res.json();
        setAppointments(data.appointments || []);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const updateStatus = async (id: string, status: string) => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/appointments/${id}/status`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ status })
      });
      
      if (res.ok) {
        setAppointments(appointments.map(a => 
          a.id === id ? { ...a, status } : a
        ));
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
          <h1 className="text-3xl font-bold text-text-main">Patient Appointments</h1>
          <Button onClick={() => router.push('/dashboard')}>Back to Dashboard</Button>
        </div>

        {appointments.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext">No appointments yet</p>
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
                    apt.status === 'COMPLETED' ? 'bg-blue-100 text-blue-700' :
                    'bg-red-100 text-red-700'
                  }`}>
                    {apt.status}
                  </span>
                </div>
                
                <p className="text-subtext text-sm mb-2">
                  Date: {new Date(apt.appointment_date).toLocaleString()}
                </p>
                
                <p className="text-subtext text-sm mb-2">
                  Duration: {apt.duration_minutes} minutes
                </p>
                
                {apt.reason && (
                  <p className="text-subtext text-sm mb-4">
                    Reason: {apt.reason}
                  </p>
                )}
                
                <div className="flex gap-2 mt-4">
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
            ))}
          </div>
        )}
      </div>
    </div>
  );
}