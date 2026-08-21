'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import {
  FileText, CalendarDays, Pill, Activity, FolderOpen, Share2,
  HeartPulse, Users, Inbox, CalendarClock, Clock, type LucideIcon,
} from 'lucide-react';
import { Card } from '@/components/ui/card';
import { PeopleICareFor } from '@/components/people-i-care-for';

interface DashboardLink {
  href: string;
  title: string;
  desc: string;
  icon: LucideIcon;
}

const links: DashboardLink[] = [
  { href: '/reports', title: 'Medical Reports', desc: 'View and generate health reports', icon: FileText },
  { href: '/appointments', title: 'Appointments', desc: 'Schedule and manage appointments', icon: CalendarDays },
  { href: '/medicines', title: 'Medicines', desc: 'Track your medications', icon: Pill },
  { href: '/vitals', title: 'Vital Signs', desc: 'Track BP, heart rate, weight, blood sugar', icon: Activity },
  { href: '/documents', title: 'Documents', desc: 'Upload and manage medical documents', icon: FolderOpen },
  { href: '/share', title: 'Share Records', desc: 'Securely share your medical data', icon: Share2 },
  { href: '/emergency', title: 'Emergency ID', desc: 'Blood type and emergency contacts', icon: HeartPulse },
  { href: '/settings/caretakers', title: 'Caretakers', desc: 'Let someone help manage your medicines', icon: Users },
  { href: '/shared-with-me', title: 'Shared with me', desc: 'Records others shared that you saved', icon: Inbox },
];

// Doctors are the likeliest recipients of a share link, so "Shared with me"
// matters more here than on the patient side, not less.
const doctorLinks: DashboardLink[] = [
  { href: '/doctor/appointments', title: 'Patient Appointments', desc: 'View appointments booked by patients', icon: CalendarClock },
  { href: '/doctor/availability', title: 'My Availability', desc: 'Set your working hours', icon: Clock },
  { href: '/shared-with-me', title: 'Shared with me', desc: 'Patient records shared with you', icon: Inbox },
];

interface SessionUser {
  id: string;
  name: string;
  email: string;
  role: string;
}

export default function Dashboard() {
  const [user] = useState<SessionUser | null>(() => {
    if (typeof window === 'undefined') return null;
    try {
      const u = localStorage.getItem('user');
      return u ? (JSON.parse(u) as SessionUser) : null;
    } catch { return null; }
  });

  // Set by /care/[patientId] when a link was revoked mid-session. Read once,
  // and consumed immediately so a stale notice never reappears on reload.
  const [notice] = useState(() => {
    if (typeof window === 'undefined') return '';
    const pending = sessionStorage.getItem('care:notice');
    if (pending) sessionStorage.removeItem('care:notice');
    return pending || '';
  });

  useEffect(() => {
    if (!user) {
      window.location.href = '/auth/login';
    }
  }, [user]);

  if (!user) return null;

  const isDoctor = user.role === 'DOCTOR';
  const items = isDoctor ? doctorLinks : links;

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl sm:text-3xl font-display font-bold text-on-surface mb-8">
          {isDoctor ? 'Doctor Dashboard' : `Welcome, ${user.name}`}
        </h1>

        {notice && (
          <div className="mb-6 rounded-md border border-caution/40 bg-caution-container px-4 py-2.5 text-sm text-caution">
            {notice}
          </div>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {items.map(link => (
            <Link key={link.href} href={link.href}>
              <Card className="p-lg h-full hover:border-primary/50 transition-colors group">
                <div className="flex items-start gap-sm">
                  <div className="w-10 h-10 bg-primary/10 text-primary rounded-sm flex items-center justify-center shrink-0">
                    <link.icon className="w-5 h-5" />
                  </div>
                  <div className="min-w-0">
                    <h2 className="text-base font-display font-semibold text-on-surface mb-1 group-hover:text-primary transition-colors">
                      {link.title}
                    </h2>
                    <p className="text-sm text-on-surface-variant">{link.desc}</p>
                  </div>
                </div>
              </Card>
            </Link>
          ))}
        </div>

        {/* Caretaker section: renders nothing unless this user has links. */}
        {!isDoctor && <PeopleICareFor />}
      </div>
    </div>
  );
}