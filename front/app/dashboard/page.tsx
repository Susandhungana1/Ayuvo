'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { PeopleICareFor } from '@/components/people-i-care-for';

const links = [
  { href: '/reports', title: 'Medical Reports', desc: 'View and generate health reports' },
  { href: '/appointments', title: 'Appointments', desc: 'Schedule and manage appointments' },
  { href: '/medicines', title: 'Medicines', desc: 'Track your medications' },
  { href: '/vitals', title: 'Vital Signs', desc: 'Track BP, heart rate, weight, blood sugar' },
  { href: '/documents', title: 'Documents', desc: 'Upload and manage medical documents' },
  { href: '/share', title: 'Share Records', desc: 'Securely share your medical data' },
  { href: '/emergency', title: 'Emergency ID', desc: 'Blood type, allergies, emergency contacts' },
  { href: '/timeline', title: 'Timeline', desc: 'Chronological view of all health events' },
  { href: '/settings/caretakers', title: 'Caretakers', desc: 'Let someone help manage your medicines' },
  { href: '/shared-with-me', title: 'Shared with me', desc: 'Records others shared that you saved' },
];

// Doctors are the likeliest recipients of a share link, so "Shared with me"
// matters more here than on the patient side, not less.
const doctorLinks = [
  { href: '/doctor/appointments', title: 'Patient Appointments', desc: 'View appointments booked by patients' },
  { href: '/doctor/availability', title: 'My Availability', desc: 'Set your working hours' },
  { href: '/shared-with-me', title: 'Shared with me', desc: 'Patient records shared with you' },
];

export default function Dashboard() {
  const [user, setUser] = useState<any>(null);
  const [notice, setNotice] = useState('');

  useEffect(() => {
    const userData = localStorage.getItem('user');
    if (!userData) { window.location.href = '/auth/login'; return; }
    setUser(JSON.parse(userData));

    // Set by /care/[patientId] when a link was revoked mid-session.
    const pending = sessionStorage.getItem('care:notice');
    if (pending) {
      setNotice(pending);
      sessionStorage.removeItem('care:notice');
    }
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

        {notice && (
          <div className="mb-6 rounded-lg border border-amber-200 bg-amber-50 px-4 py-2.5 text-sm text-amber-900">
            {notice}
          </div>
        )}

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

        {/* Caretaker section: renders nothing unless this user has links. */}
        {!isDoctor && <PeopleICareFor />}
      </div>
    </div>
  );
}
