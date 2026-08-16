import { ShieldCheck, CalendarDays, Activity, ExternalLink } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { StatusChip } from '@/components/ui/status-chip';
import { RangeBar } from '@/components/ui/range-bar';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'About Us - MediStore',
  description: 'MediStore is a product of Quorlyn — a secure platform to store medical records, track vital signs, manage medications, and share health data with doctors.',
};

const FOUNDERS = [
  {
    name: 'Susan Dhungana',
    role: 'Co-Founder & Director',
    initials: 'SD',
    color: 'bg-ok-container text-ok',
  },
  {
    name: 'Sandip Bhusal',
    role: 'Co-Founder & Director',
    initials: 'SB',
    color: 'bg-primary/10 text-primary',
  },
  {
    name: 'Anuj Bhusal',
    role: 'Co-Founder & Director',
    initials: 'AB',
    color: 'bg-caution-container text-caution',
  },
];

export default function About() {
  return (
    <div className="bg-surface min-h-screen py-16">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <h1 className="text-4xl md:text-5xl font-display font-bold text-on-surface mb-6">About MediStore</h1>
          <p className="text-lg text-on-surface-variant leading-relaxed">
            MediStore is your personal digital health store — a secure platform to store
            medical records, track vital signs, manage medications, book appointments,
            generate reports, and share your health data with doctors — all in one place.
          </p>
          <p className="text-sm text-on-surface-variant mt-4">
            A product of{' '}
            <a
              href="https://www.quorlyn.com.np"
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary hover:underline font-medium inline-flex items-center gap-1"
            >
              Quorlyn <ExternalLink size={12} />
            </a>
          </p>
        </div>

        {/* Our Company */}
        <div className="mb-24">
          <Card className="p-xl md:p-2xl">
            <div className="flex flex-col md:flex-row md:items-center gap-8">
              <div className="flex-1">
                <h2 className="text-3xl font-display font-bold text-on-surface mb-4">Our Company</h2>
                <p className="text-on-surface-variant leading-relaxed mb-4">
                  MediStore is built and published by{' '}
                  <a
                    href="https://www.quorlyn.com.np"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-primary hover:underline font-medium"
                  >
                    Quorlyn
                  </a>
                  , a technology company focused on products that make everyday life simpler and
                  more secure. Quorlyn brings together a team of founders and directors who care
                  about building software that people can trust with what matters most.
                </p>
                <a
                  href="https://www.quorlyn.com.np"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 text-primary hover:underline font-medium"
                >
                  Visit quorlyn.com.np <ExternalLink size={14} />
                </a>
              </div>
              <div className="w-full md:w-64 h-40 rounded-lg bg-surface-card border border-outline flex flex-col items-center justify-center gap-2 shrink-0">
                <p className="text-xl font-display font-bold text-on-surface">Quorlyn</p>
                <p className="text-xs text-on-surface-variant">Building MediStore</p>
              </div>
            </div>
          </Card>
        </div>

        {/* Founders */}
        <div className="mb-24">
          <h2 className="text-3xl font-display font-bold text-on-surface text-center mb-4">Meet the Founders</h2>
          <p className="text-on-surface-variant text-center max-w-2xl mx-auto mb-12">
            The three founders and directors behind Quorlyn, and the team that built MediStore.
          </p>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
            {FOUNDERS.map((founder) => (
              <Card key={founder.name} className="p-lg text-center">
                <div className={`w-20 h-20 ${founder.color} rounded-full flex items-center justify-center mx-auto mb-5`}>
                  <span className="text-2xl font-display font-bold">{founder.initials}</span>
                </div>
                <h3 className="text-lg font-display font-bold text-on-surface mb-1">{founder.name}</h3>
                <p className="text-sm text-on-surface-variant">{founder.role}</p>
              </Card>
            ))}
          </div>
        </div>

        {/* What We Do */}
        <div className="mb-24">
          <Card className="p-xl md:p-2xl flex flex-col md:flex-row gap-12 items-center">
            <div className="flex-1">
              <h2 className="text-3xl font-display font-bold text-on-surface mb-6">What We Do</h2>
              <p className="text-on-surface-variant mb-4 leading-relaxed">
                MediStore lets you upload and organize lab results, prescriptions, and
                medical history, track vital signs like blood pressure, heart rate, blood
                sugar, and weight, manage your medications with dose reminders, book
                appointments with doctors, generate AI-powered medical reports, and share
                records securely via expiring links.
              </p>
            </div>
            {/* The range-bar grammar, standing in as the illustration */}
            <div className="flex-1 w-full bg-surface-card border border-outline rounded-lg p-xl flex flex-col justify-center gap-lg min-h-[300px]">
              <p className="text-xs font-semibold uppercase tracking-wider text-on-surface-variant">
                Every reading, judged against its band
              </p>
              <div>
                <div className="flex items-baseline justify-between mb-1">
                  <p className="text-sm font-medium text-on-surface">Blood pressure</p>
                  <p className="text-lg font-display font-semibold text-on-surface tabular-nums">128/82</p>
                </div>
                <RangeBar min={40} max={240} bandStart={90} bandEnd={120} value={128} className="mb-1.5" />
                <StatusChip level="caution" label="Elevated" trend="up" />
              </div>
              <div>
                <div className="flex items-baseline justify-between mb-1">
                  <p className="text-sm font-medium text-on-surface">Heart rate</p>
                  <p className="text-lg font-display font-semibold text-on-surface tabular-nums">72 bpm</p>
                </div>
                <RangeBar min={30} max={200} bandStart={60} bandEnd={100} value={72} className="mb-1.5" />
                <StatusChip level="ok" label="Normal" />
              </div>
              <div>
                <div className="flex items-baseline justify-between mb-1">
                  <p className="text-sm font-medium text-on-surface">Oxygen saturation</p>
                  <p className="text-lg font-display font-semibold text-on-surface tabular-nums">97%</p>
                </div>
                <RangeBar min={60} max={100} bandStart={95} bandEnd={100} value={97} className="mb-1.5" />
                <StatusChip level="ok" label="Normal" />
              </div>
              <p className="text-xs text-on-surface-variant">
                Example readings — not your data.
              </p>
            </div>
          </Card>
        </div>

        {/* Why Choose Us */}
        <div>
          <h2 className="text-3xl font-display font-bold text-on-surface text-center mb-12">Why Choose Us</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <Card className="p-lg text-center">
              <div className="w-16 h-16 bg-ok-container text-ok rounded-full flex items-center justify-center mx-auto mb-6">
                <Activity size={32} />
              </div>
              <h3 className="text-xl font-display font-bold text-on-surface mb-3">Vitals & Medicines</h3>
              <p className="text-on-surface-variant">Track blood pressure, heart rate, blood sugar, and more. Manage your medications with intelligent dose reminders.</p>
            </Card>

            <Card className="p-lg text-center">
              <div className="w-16 h-16 bg-primary/10 text-primary rounded-full flex items-center justify-center mx-auto mb-6">
                <CalendarDays size={32} />
              </div>
              <h3 className="text-xl font-display font-bold text-on-surface mb-3">Reports & Appointments</h3>
              <p className="text-on-surface-variant">Generate detailed medical reports and book appointments with doctors directly through the platform.</p>
            </Card>

            <Card className="p-lg text-center">
              <div className="w-16 h-16 bg-ok-container text-ok rounded-full flex items-center justify-center mx-auto mb-6">
                <ShieldCheck size={32} />
              </div>
              <h3 className="text-xl font-display font-bold text-on-surface mb-3">Secure & Private</h3>
              <p className="text-on-surface-variant">Your data is encrypted in transit, locked behind your account, and shared only through expiring links you control.</p>
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
}