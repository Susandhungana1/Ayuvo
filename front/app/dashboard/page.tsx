'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function Dashboard() {
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    const userData = localStorage.getItem('user');
    if (!userData) {
      window.location.href = '/auth/login';
    } else {
      setUser(JSON.parse(userData));
    }
  }, []);

  if (!user) return null;

  const isDoctor = user.role === 'DOCTOR';

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-text-main">
            {isDoctor ? 'Doctor Dashboard' : `Welcome, ${user.name}`}
          </h1>
        </div>

        {isDoctor ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <Link href="/doctor/appointments">
              <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow cursor-pointer">
                <h2 className="text-xl font-semibold text-text-main mb-2">Patient Appointments</h2>
                <p className="text-subtext">View appointments booked by patients</p>
              </div>
            </Link>

            <Link href="/doctor/chat">
              <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow cursor-pointer">
                <h2 className="text-xl font-semibold text-text-main mb-2">Patient Messages</h2>
                <p className="text-subtext">View and respond to patient chats</p>
              </div>
            </Link>

            <Link href="/doctor/availability">
              <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow cursor-pointer">
                <h2 className="text-xl font-semibold text-text-main mb-2">My Availability</h2>
                <p className="text-subtext">Set your working hours</p>
              </div>
            </Link>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <Link href="/reports">
              <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow cursor-pointer">
                <h2 className="text-xl font-semibold text-text-main mb-2">Medical Reports</h2>
                <p className="text-subtext">View and generate health reports</p>
              </div>
            </Link>

            <Link href="/appointments">
              <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow cursor-pointer">
                <h2 className="text-xl font-semibold text-text-main mb-2">Appointments</h2>
                <p className="text-subtext">Schedule and manage appointments</p>
              </div>
            </Link>

            <Link href="/medicines">
              <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow cursor-pointer">
                <h2 className="text-xl font-semibold text-text-main mb-2">Medicines</h2>
                <p className="text-subtext">Track your medications</p>
              </div>
            </Link>

            <Link href="/chat">
              <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow cursor-pointer">
                <h2 className="text-xl font-semibold text-text-main mb-2">Chat with Doctor</h2>
                <p className="text-subtext">Message your healthcare provider</p>
              </div>
            </Link>

            <Link href="/share">
              <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow cursor-pointer">
                <h2 className="text-xl font-semibold text-text-main mb-2">Share Records</h2>
                <p className="text-subtext">Securely share your medical data</p>
              </div>
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}