'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';

const links = [
  { href: '/reports', title: 'Medical Reports', desc: 'View and generate health reports' },
  { href: '/appointments', title: 'Appointments', desc: 'Schedule and manage appointments' },
  { href: '/medicines', title: 'Medicines', desc: 'Track your medications' },
  { href: '/vitals', title: 'Vital Signs', desc: 'Track BP, heart rate, weight, blood sugar' },
  { href: '/documents', title: 'Documents', desc: 'Upload and manage medical documents' },
  { href: '/share', title: 'Share Records', desc: 'Securely share your medical data' },
  { href: '/emergency', title: 'Emergency ID', desc: 'Blood type, allergies, emergency contacts' },
  { href: '/timeline', title: 'Timeline', desc: 'Chronological view of all health events' },
];

const doctorLinks = [
  { href: '/doctor/appointments', title: 'Patient Appointments', desc: 'View appointments booked by patients' },
  { href: '/doctor/availability', title: 'My Availability', desc: 'Set your working hours' },
];

export default function Dashboard() {
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    const userData = localStorage.getItem('user');
    if (!userData) { window.location.href = '/auth/login'; return; }
    setUser(JSON.parse(userData));
  }, []);

  if (!user) return null;

  const isDoctor = user.role === 'DOCTOR';
  const items = isDoctor ? doctorLinks : links;

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-text-main mb-8">
          {isDoctor ? 'Doctor Dashboard' : `Welcome, ${user.name}`}
        </h1>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {items.map(link => (
            <Link key={link.href} href={link.href}>
              <div className="bg-white rounded-xl p-5 border border-gray-100 hover:border-gray-200 hover:shadow-sm transition-all cursor-pointer">
                <h2 className="text-base font-semibold text-text-main mb-1">{link.title}</h2>
                <p className="text-sm text-subtext">{link.desc}</p>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
