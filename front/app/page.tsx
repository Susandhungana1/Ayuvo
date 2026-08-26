'use client';

import { useEffect, useState, useCallback } from 'react';
import { apiFetch, API_URL } from '@/lib/api';
import { analyzeBP, analyzeHR, analyzeSugar, analyzeTemp, analyzeSpO2, type VitalBand } from '@/lib/status';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';

interface Medicine {
  id: string;
  name: string;
  dosage: string;
  frequency: string;
  start_date: string;
  end_date?: string;
  taking_times?: string;
  notes?: string;
}

interface VitalSign {
  id: string;
  blood_pressure_systolic: number | null;
  blood_pressure_diastolic: number | null;
  heart_rate: number | null;
  weight: number | null;
  blood_sugar: number | null;
  temperature: number | null;
  oxygen_saturation: number | null;
  notes: string | null;
  measured_at: string;
}

interface IntakeEntry {
  medicine_id: string;
  scheduled_time: string;
  status: string;
  recorded_at: string;
}

interface Appointment {
  id: string;
  title: string;
  doctor_name?: string | null;
  hospital?: string | null;
  appointment_date: string;
  status: string;
}

interface Report {
  id: string;
  report_type: string;
  report_date?: string | null;
}

// Band classification lives in lib/status.ts — the same engine as /vitals.
// This page only maps its output (level + label) onto this page's chip
// colours, so a threshold change is edited once, not twice.
const BAND_STYLES: Record<string, Record<string, { color: string; bg: string; border: string }>> = {
  bp: {
    Low: { color: 'text-rose-700', bg: 'bg-rose-50', border: 'border-rose-200' },
    Normal: { color: 'text-green-700', bg: 'bg-green-50', border: 'border-green-200' },
    Elevated: { color: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' },
    'Stage 1': { color: 'text-orange-700', bg: 'bg-orange-50', border: 'border-orange-200' },
    'Stage 2': { color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' },
    Crisis: { color: 'text-red-800', bg: 'bg-red-100', border: 'border-red-300' },
  },
  hr: {
    Low: { color: 'text-rose-700', bg: 'bg-rose-50', border: 'border-rose-200' },
    Normal: { color: 'text-green-700', bg: 'bg-green-50', border: 'border-green-200' },
    Elevated: { color: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' },
    High: { color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' },
  },
  sugar: {
    Low: { color: 'text-rose-700', bg: 'bg-rose-50', border: 'border-rose-200' },
    Normal: { color: 'text-green-700', bg: 'bg-green-50', border: 'border-green-200' },
    Prediabetic: { color: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' },
    High: { color: 'text-orange-700', bg: 'bg-orange-50', border: 'border-orange-200' },
    'Very High': { color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' },
  },
  temp: {
    Hypothermia: { color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' },
    Low: { color: 'text-rose-700', bg: 'bg-rose-50', border: 'border-rose-200' },
    Normal: { color: 'text-green-700', bg: 'bg-green-50', border: 'border-green-200' },
    'Mild Fever': { color: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' },
    Fever: { color: 'text-orange-700', bg: 'bg-orange-50', border: 'border-orange-200' },
    'High Fever': { color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' },
  },
  spo2: {
    Normal: { color: 'text-green-700', bg: 'bg-green-50', border: 'border-green-200' },
    'Mild Low': { color: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' },
    Low: { color: 'text-orange-700', bg: 'bg-orange-50', border: 'border-orange-200' },
    Critical: { color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' },
  },
};

function chip(key: keyof typeof BAND_STYLES, band: VitalBand) {
  const style = BAND_STYLES[key][band.label] ?? { color: 'text-gray-700', bg: 'bg-gray-50', border: 'border-gray-200' };
  return { status: band.label, ...style };
}

export default function Home() {
  const router = useRouter();
  const [user, setUser] = useState<any>(null);
  const [medicines, setMedicines] = useState<Medicine[]>([]);
  const [medsLoading, setMedsLoading] = useState(true);
  const [vitals, setVitals] = useState<VitalSign[]>([]);
  const [vitalsLoading, setVitalsLoading] = useState(true);
  const [nextDose, setNextDose] = useState<{ name: string; time: string; remaining: string } | null>(null);
  const [intakeLog, setIntakeLog] = useState<IntakeEntry[]>([]);
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [reports, setReports] = useState<Report[]>([]);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const syncUser = () => {
      const token = localStorage.getItem('token');
      const userData = localStorage.getItem('user');
      setUser(token && userData ? JSON.parse(userData) : null);
    };
    syncUser();
    setMounted(true);
    window.addEventListener('localStorageUpdated', syncUser);
    window.addEventListener('storage', syncUser);
    return () => {
      window.removeEventListener('localStorageUpdated', syncUser);
      window.removeEventListener('storage', syncUser);
    };
  }, []);

  const isPatient = user && user.role !== 'DOCTOR';

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token || !isPatient) { setMedsLoading(false); setVitalsLoading(false); return; }

    const fetchMeds = async () => {
      try {
        const res = await apiFetch(`${API_URL}/api/medicines`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (res.ok) { const d = await res.json(); setMedicines(d.medicines || []); }
      } catch (e) { console.error(e); } finally { setMedsLoading(false); }
    };

    const fetchVitals = async () => {
      try {
        const res = await apiFetch(`${API_URL}/api/vitals?limit=20`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (res.ok) { const d = await res.json(); setVitals(d.vitals || []); }
      } catch (e) { console.error(e); } finally { setVitalsLoading(false); }
    };

    const fetchIntake = async () => {
      try {
        const res = await apiFetch(`${API_URL}/api/medicines/intake/log?limit=200`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (res.ok) { const d = await res.json(); setIntakeLog(d.intakes || []); }
      } catch (e) { console.error(e); }
    };

    const fetchAppointments = async () => {
      try {
        const res = await apiFetch(`${API_URL}/api/appointments`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (res.ok) { const d = await res.json(); setAppointments(d.appointments || []); }
      } catch (e) { console.error(e); }
    };

    const fetchReports = async () => {
      try {
        const res = await apiFetch(`${API_URL}/api/reports?offset=0&limit=1`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (res.ok) { const d = await res.json(); setReports(d.reports || []); }
      } catch (e) { console.error(e); }
    };

    if (isPatient) { fetchMeds(); fetchVitals(); fetchIntake(); fetchAppointments(); fetchReports(); }
    else { setMedsLoading(false); setVitalsLoading(false); }
  }, [isPatient]);

  const updateNextDose = useCallback(() => {
    const now = new Date();
    const today = now.toISOString().slice(0, 10);
    const curMin = now.getHours() * 60 + now.getMinutes();
    let closest: { name: string; time: string; diff: number } | null = null;

    for (const med of medicines) {
      if (med.start_date > today || (med.end_date && med.end_date < today)) continue;
      let times: string[] = [];
      if (med.taking_times) { try { times = JSON.parse(med.taking_times); } catch { times = []; } }
      for (const t of times) {
        const [h, m] = t.split(':').map(Number);
        const diff = h * 60 + m - curMin;
        if (diff >= 0 && (!closest || diff < closest.diff)) closest = { name: med.name, time: t, diff };
      }
    }

    if (closest) {
      const hrs = Math.floor(closest.diff / 60), mins = closest.diff % 60;
      setNextDose({ name: closest.name, time: closest.time, remaining: hrs > 0 ? `${hrs}h ${mins}m` : `${mins}m` });
    } else setNextDose(null);
  }, [medicines]);

  useEffect(() => { updateNextDose(); const i = setInterval(updateNextDose, 30000); return () => clearInterval(i); }, [updateNextDose]);

  const isDoctor = user?.role === 'DOCTOR';
  const parseTimes = (tt?: string): string[] => {
    if (!tt) return [];
    try { return JSON.parse(tt); } catch { return []; }
  };

  const today = mounted ? new Date().toISOString().slice(0, 10) : '';
  const latestVital = vitals[0];

  // Consecutive full days ending yesterday — mirrors home_screen.dart so both
  // platforms quote the same number. Days with no schedule are neutral.
  const adherenceStreak = (() => {
    if (!mounted || medicines.length === 0) return 0;
    const taken = new Set(
      intakeLog
        .filter(l => l.status === 'taken' && l.recorded_at)
        .map(l => `${l.medicine_id}-${l.scheduled_time}@${l.recorded_at.slice(0, 10)}`)
    );
    const pad = (n: number) => String(n).padStart(2, '0');
    let streak = 0;
    for (let back = 1; back <= 30; back++) {
      const d = new Date();
      d.setDate(d.getDate() - back);
      const key = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
      const slots: string[] = [];
      for (const med of medicines) {
        if (med.start_date > key || (med.end_date && med.end_date < key)) continue;
        for (const t of parseTimes(med.taking_times)) slots.push(`${med.id}-${t}@${key}`);
      }
      if (slots.length === 0) continue;
      if (!slots.every(s => taken.has(s))) return streak;
      streak++;
    }
    return streak;
  })();

  const agoLabel = latestVital?.measured_at ? (() => {
    const mins = Math.floor((Date.now() - new Date(latestVital.measured_at).getTime()) / 60000);
    if (mins < 1) return 'just now';
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    return `${Math.floor(hrs / 24)}d ago`;
  })() : '';

  // Next appointment that has not been cancelled and is still ahead.
  const nextAppointment = (() => {
    const nowMs = mounted ? Date.now() : 0;
    return appointments
      .filter(a => a.status !== 'CANCELLED' && a.status !== 'cancelled')
      .map(a => ({ ...a, at: new Date(a.appointment_date).getTime() }))
      .filter(a => !Number.isNaN(a.at) && a.at >= nowMs)
      .sort((a, b) => a.at - b.at)[0] ?? null;
  })();

  const latestReport = reports[0] ?? null;

  const fmtAppt = (iso: string) => new Date(iso).toLocaleString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  });
  const fmtDate = (iso?: string | null) => iso
    ? new Date(iso).toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' })
    : null;

  // Tomorrow's dose plan — forward-looking, never judgmental. Same slot
  // arithmetic as the app's home_screen.dart.
  const tomorrowPlan = (() => {
    if (!mounted || medicines.length === 0) return [];
    const d = new Date();
    d.setDate(d.getDate() + 1);
    const pad = (n: number) => String(n).padStart(2, '0');
    const key = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    const slots: { time: string; name: string }[] = [];
    for (const med of medicines) {
      if (med.start_date > key || (med.end_date && med.end_date < key)) continue;
      for (const t of parseTimes(med.taking_times)) slots.push({ time: t, name: med.name });
    }
    return slots.sort((a, b) => a.time.localeCompare(b.time));
  })();

  const tomorrowLabel = (() => {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return d.toLocaleDateString('en-US', { weekday: 'short' });
  })();

  return (
    <div className="bg-[var(--color-background)]">
      {/* HEADER — consistent with other pages */}
      {isDoctor ? (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="text-center max-w-xl mx-auto">
            <h1 className="text-3xl font-bold text-[var(--color-ink)] font-heading mb-3">Doctor Dashboard</h1>
            <p className="text-[var(--color-ink-variant)] mb-6">Manage your patient appointments and availability.</p>
            <Link href="/dashboard"><Button variant="primary">Go to Dashboard</Button></Link>
          </div>
        </div>
      ) : user ? (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
            <div>
              <h1 className="text-2xl sm:text-3xl font-bold text-[var(--color-ink)] font-heading">
                Welcome, {user.name?.split(' ')[0] || 'User'}
              </h1>
              <p className="text-[var(--color-ink-variant)] text-sm mt-1">
                {mounted ? new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }) : '\u00A0'}
              </p>
            </div>
            <Link href="/dashboard">
              <Button variant="primary">Dashboard</Button>
            </Link>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
            {/* Today's Medicines — the reason people open Ayuvo, so it
                leads both on desktop and in mobile stacking order. */}
            <div className="lg:col-span-2">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-semibold text-[var(--color-ink)] font-heading">Today's Medicines</h2>
                <Link href="/medicines" className="text-sm text-[var(--color-primary)] hover:underline">Manage</Link>
              </div>

              {adherenceStreak >= 2 && (
                <div className="inline-flex items-center gap-1.5 mb-3 px-2.5 py-1 rounded-full bg-[var(--color-ok-container)]">
                  <span className="text-sm" aria-hidden>🔥</span>
                  <span className="text-xs font-semibold text-[var(--color-ok)]">{adherenceStreak}-day streak</span>
                </div>
              )}
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-semibold text-[var(--color-ink)] font-heading">Today's Medicines</h2>
                <Link href="/medicines" className="text-sm text-[var(--color-primary)] hover:underline">Manage</Link>
              </div>

              {nextDose && (
                <div className="bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-md)] p-5 border border-[var(--color-ok-container)] dark:border-[var(--color-ok)] mb-4">
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 bg-[var(--color-ok-container)] rounded-[var(--radius-sm)] flex items-center justify-center shrink-0">
                      <span className="text-[var(--color-ok)] text-lg">&#9679;</span>
                    </div>
                    <div>
                      <p className="text-xs font-semibold text-[var(--color-ok)] uppercase tracking-wider">Next dose</p>
                      <p className="text-sm font-semibold text-[var(--color-ink)] mt-0.5">{nextDose.name}</p>
                      <p className="text-xs text-[var(--color-ink-variant)] mt-0.5">{nextDose.time} &mdash; <span className="text-[var(--color-ok)] font-medium">{nextDose.remaining} left</span></p>
                    </div>
                  </div>
                </div>
              )}

              {medsLoading ? (
                <div className="space-y-3">
                  {[1,2].map(i => (
                    <div key={i} className="bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-md)] p-5 border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] animate-pulse">
                      <div className="h-4 bg-[var(--color-muted)] rounded w-24 mb-2" />
                      <div className="h-3 bg-[var(--color-muted)] rounded w-16" />
                    </div>
                  ))}
                </div>
              ) : medicines.filter(m => !m.end_date || m.end_date >= today).length > 0 ? (
                <div className="space-y-3">
                  {medicines.filter(m => !m.end_date || m.end_date >= today).map(med => {
                    const times = parseTimes(med.taking_times);
                    const now = mounted ? new Date() : null;
                    const curMin = now ? now.getHours() * 60 + now.getMinutes() : 0;
                    return (
                      <div key={med.id} className="bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-md)] p-5 border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)]">
                        <div className="flex items-start gap-3">
                          <div className="w-9 h-9 bg-[var(--color-primary-light)] rounded-[var(--radius-sm)] flex items-center justify-center shrink-0 mt-0.5">
                            <span className="text-[var(--color-primary)] text-sm font-bold">Rx</span>
                          </div>
                          <div>
                            <p className="text-sm font-semibold text-[var(--color-ink)]">{med.name}</p>
                            <p className="text-xs text-[var(--color-ink-variant)] mb-2">{med.dosage}</p>
                            {times.length > 0 && (
                              <div className="flex flex-wrap gap-1.5">
                                {times.map((t, i) => {
                                  const [h, m] = t.split(':').map(Number);
                                  const isPast = h * 60 + m < curMin;
                                  return (
                                    <span key={i} className={`inline-flex items-center px-2 py-0.5 rounded-[var(--radius-sm)] text-xs font-medium ${
                                      isPast ? 'bg-[var(--color-muted)] text-[var(--color-ink-muted)] line-through' : 'bg-[var(--color-primary-light)] text-[var(--color-primary)]'
                                    }`}>
                                      {t}
                                    </span>
                                  );
                                })}
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <Card className="p-8 text-center">
                  <p className="text-[var(--color-ink-variant)] mb-4">No medicines added yet</p>
                  <Link href="/medicines"><Button>Add Medicines</Button></Link>
                </Card>
              )}
            </div>

            {/* Health — one thin strip of chips; full detail and trends live
                in /vitals, so home only answers "am I OK?" at a glance. */}
            <div className="lg:col-span-3">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-semibold text-[var(--color-ink)] font-heading">Health</h2>
                <Link href="/vitals" className="text-sm text-[var(--color-primary)] hover:underline">View all</Link>
              </div>

              {vitalsLoading ? (
                <div className="bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-md)] p-5 border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] animate-pulse">
                  <div className="h-8 bg-[var(--color-muted)] rounded w-3/4" />
                </div>
              ) : latestVital ? (
                <Link href="/vitals" className="block group">
                  <div className="bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-md)] p-4 border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] group-hover:border-[var(--color-primary)] transition-colors">
                    <div className="flex items-center gap-6 overflow-x-auto pb-1">
                      {latestVital.blood_pressure_systolic && latestVital.blood_pressure_diastolic && (() => {
                        const bp = chip('bp', analyzeBP(latestVital.blood_pressure_systolic, latestVital.blood_pressure_diastolic));
                        return (
                          <div className="shrink-0">
                            <p className="text-lg font-bold text-text-main leading-tight">{latestVital.blood_pressure_systolic}/{latestVital.blood_pressure_diastolic}</p>
                            <p className={`text-xs font-medium ${bp.color}`}>BP · {bp.status}</p>
                          </div>
                        );
                      })()}
                      {latestVital.heart_rate && (() => {
                        const hr = chip('hr', analyzeHR(latestVital.heart_rate));
                        return (
                          <div className="shrink-0">
                            <p className="text-lg font-bold text-text-main leading-tight">{latestVital.heart_rate}</p>
                            <p className={`text-xs font-medium ${hr.color}`}>Heart · {hr.status}</p>
                          </div>
                        );
                      })()}
                      {latestVital.blood_sugar && (() => {
                        const sg = chip('sugar', analyzeSugar(latestVital.blood_sugar));
                        return (
                          <div className="shrink-0">
                            <p className="text-lg font-bold text-text-main leading-tight">{Math.round(latestVital.blood_sugar)}</p>
                            <p className={`text-xs font-medium ${sg.color}`}>Sugar · {sg.status}</p>
                          </div>
                        );
                      })()}
                      {latestVital.temperature && (() => {
                        const t = chip('temp', analyzeTemp(latestVital.temperature));
                        return (
                          <div className="shrink-0">
                            <p className="text-lg font-bold text-text-main leading-tight">{latestVital.temperature.toFixed(1)}°C</p>
                            <p className={`text-xs font-medium ${t.color}`}>Temp · {t.status}</p>
                          </div>
                        );
                      })()}
                      {latestVital.oxygen_saturation && (() => {
                        const o = chip('spo2', analyzeSpO2(latestVital.oxygen_saturation));
                        return (
                          <div className="shrink-0">
                            <p className="text-lg font-bold text-text-main leading-tight">{latestVital.oxygen_saturation}%</p>
                            <p className={`text-xs font-medium ${o.color}`}>SpO₂ · {o.status}</p>
                          </div>
                        );
                      })()}
                      {latestVital.weight && (
                        <div className="shrink-0">
                          <p className="text-lg font-bold text-text-main leading-tight">{latestVital.weight.toFixed(1)} kg</p>
                          <p className="text-xs font-medium text-blue-700">Weight · Recorded</p>
                        </div>
                      )}
                      <span className="text-[var(--color-ink-variant)] shrink-0 ml-auto" aria-hidden>›</span>
                    </div>
                    {agoLabel && (
                      <p className="text-xs text-[var(--color-ink-variant)] mt-2">Measured {agoLabel}</p>
                    )}
                  </div>
                </Link>
              ) : (
                <Card className="p-8 text-center">
                  <p className="text-subtext mb-4">No vital signs recorded yet</p>
                  <Link href="/vitals"><Button>Record Your First Reading</Button></Link>
                </Card>
              )}

              {/* Quick links */}
              <div className="grid grid-cols-3 gap-4 mt-6">
                <Link href="/appointments">
                  <div className="bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-md)] p-4 border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] hover:border-[var(--color-primary)] transition-colors text-center">
                    <p className="text-sm font-medium text-[var(--color-ink)]">Appointments</p>
                  </div>
                </Link>
                <Link href="/reports">
                  <div className="bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-md)] p-4 border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] hover:border-[var(--color-primary)] transition-colors text-center">
                    <p className="text-sm font-medium text-[var(--color-ink)]">Reports</p>
                  </div>
                </Link>
                <Link href="/medicines">
                  <div className="bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-md)] p-4 border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] hover:border-[var(--color-primary)] transition-colors text-center">
                    <p className="text-sm font-medium text-[var(--color-ink)]">Medicines</p>
                  </div>
                </Link>
              </div>
            </div>
          </div>

          {/* Upcoming — read-only glances after doses: nearest appointment,
              newest report, and the week's adherence. */}
          <div className="mt-6">
            {(nextAppointment || latestReport) && (
              <h2 className="text-xl font-semibold text-[var(--color-ink)] font-heading mb-4">Upcoming</h2>
            )}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              {nextAppointment && (
                <Link href="/appointments">
                  <div className="bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-md)] p-4 border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] hover:border-[var(--color-primary)] transition-colors h-full">
                    <p className="text-xs text-[var(--color-ink-variant)] mb-1">📅 Appointment</p>
                    <p className="text-sm font-semibold text-[var(--color-ink)]">{nextAppointment.title}</p>
                    {nextAppointment.doctor_name && (
                      <p className="text-xs text-[var(--color-ink-variant)]">{nextAppointment.doctor_name}</p>
                    )}
                    <p className="text-xs text-[var(--color-primary)] mt-1">{fmtAppt(nextAppointment.appointment_date)}</p>
                  </div>
                </Link>
              )}
              {latestReport && (
                <Link href="/reports">
                  <div className="bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-md)] p-4 border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] hover:border-[var(--color-primary)] transition-colors h-full">
                    <p className="text-xs text-[var(--color-ink-variant)] mb-1">📄 Latest report</p>
                    <p className="text-sm font-semibold text-[var(--color-ink)] capitalize">{latestReport.report_type.toLowerCase().replace(/_/g, ' ')}</p>
                    <p className="text-xs text-[var(--color-ink-variant)] mt-1">{fmtDate(latestReport.report_date) ?? 'Undated'}</p>
                  </div>
                </Link>
              )}
              {tomorrowPlan.length > 0 && (
                <div className="bg-white dark:bg-[var(--color-card)] rounded-[var(--radius-md)] p-4 border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] sm:col-span-2">
                  <p className="text-xs text-[var(--color-ink-variant)] mb-2">Tomorrow · {tomorrowLabel}</p>
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-x-6 gap-y-1.5">
                    {tomorrowPlan.map((s, i) => (
                      <div key={i} className="flex items-baseline gap-2">
                        <span className="text-xs font-semibold text-[var(--color-primary)] tabular-nums shrink-0">{s.time}</span>
                        <span className="text-sm text-[var(--color-ink)] truncate">{s.name}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      ) : (
        /* PUBLIC LANDING PAGE — non-logged-in */
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-20 pb-16 text-center">
          <p className="text-sm text-[var(--color-primary)] font-medium mb-3">Secure & Private</p>
          <h1 className="text-4xl md:text-5xl font-bold text-[var(--color-ink)] font-heading mb-4">
            Your Personal Digital <span className="text-[var(--color-primary)]">Health Store</span>
          </h1>
          <p className="text-[var(--color-ink-variant)] mb-8 max-w-lg mx-auto">
            Securely store, organize, and manage your medical records in one place.
          </p>
          <div className="flex items-center justify-center gap-3">
            <Link href="/auth/register"><Button variant="primary" className="text-base px-6 py-2.5">Get Started</Button></Link>
            <Link href="/about"><Button variant="outline" className="text-base px-6 py-2.5">Learn More</Button></Link>
          </div>
        </div>
      )}

      {/* MARKETING SECTIONS — non-logged-in */}
      {!user && (
        <>
          <section className="py-24 bg-white dark:bg-[var(--color-card)]">
            <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
              <div className="text-center mb-16">
                <h2 className="text-2xl font-bold text-[var(--color-ink)] font-heading mb-3">Everything You Need</h2>
                <p className="text-[var(--color-ink-variant)]">Tools to manage your health efficiently and securely.</p>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <Card>
                  <h3 className="text-lg font-semibold text-[var(--color-ink)] font-heading mb-2">Upload Records</h3>
                  <p className="text-sm text-[var(--color-ink-variant)]">Upload and organize your lab results, prescriptions, and medical history.</p>
                </Card>
                <Card>
                  <h3 className="text-lg font-semibold text-[var(--color-ink)] font-heading mb-2">Track Health</h3>
                  <p className="text-sm text-[var(--color-ink-variant)]">Monitor vitals and manage appointments from one place.</p>
                </Card>
                <Card>
                  <h3 className="text-lg font-semibold text-[var(--color-ink)] font-heading mb-2">Secure Sharing</h3>
                  <p className="text-sm text-[var(--color-ink-variant)]">Share medical records with specialists via encrypted links.</p>
                </Card>
              </div>
            </div>
          </section>

          <section className="py-20 bg-[var(--color-background)] text-center">
            <div className="max-w-md mx-auto px-4">
              <h2 className="text-2xl font-bold text-[var(--color-ink)] font-heading mb-4">Ready to Take Control?</h2>
              <p className="text-[var(--color-ink-variant)] mb-8">Join others who trust Ayuvo to securely manage their medical information.</p>
              <Link href="/auth/register"><Button variant="primary" className="text-base px-6 py-2.5">Create Free Account</Button></Link>
            </div>
          </section>

          {/* FAQ — common questions for people deciding whether to trust a
              health platform with their records. */}
          <section id="faq" className="py-20 bg-white dark:bg-[var(--color-card)]">
            <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
              <div className="text-center mb-12">
                <h2 className="text-2xl font-bold text-[var(--color-ink)] font-heading mb-3">Frequently Asked Questions</h2>
                <p className="text-[var(--color-ink-variant)] mb-4">Answers to the questions people ask before signing up.</p>
                <Link href="/faq" className="text-sm text-[var(--color-primary)] hover:underline">View all FAQs &rarr;</Link>
              </div>
              <div className="space-y-4">
                {[
                  {
                    q: 'Is my medical data safe with Ayuvo?',
                    a: 'Yes. Your data is stored securely in an encrypted database, locked behind your account, and never sold or shared without your consent. You control exactly what you share and for how long.',
                  },
                  {
                    q: 'Is Ayuvo a medical service?',
                    a: 'No. Ayuvo is a storage and management tool for your health records. It does not provide medical advice, diagnosis, or treatment. Always consult a qualified healthcare provider for medical decisions.',
                  },
                  {
                    q: 'Who can see my records?',
                    a: 'Only you, unless you deliberately share them. Doctors you book appointments with and caretakers you invite see only what you authorize, and share links expire automatically after the time you choose.',
                  },
                  {
                    q: 'How does sharing a report work?',
                    a: 'You generate a secure link with an expiry time and send it to a doctor or family member. The link opens a read-only view of that single report and stops working once it expires.',
                  },
                  {
                    q: 'Is Ayuvo free?',
                    a: 'Yes. Creating an account and using all core features — vitals, medicines, reports, appointments, and sharing — is free.',
                  },
                ].map((item) => (
                  <details key={item.q} className="group bg-[var(--color-bg)] dark:bg-[var(--color-background)] border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] rounded-[var(--radius-md)]">
                    <summary className="flex items-center justify-between gap-4 px-5 py-4 cursor-pointer font-medium text-[var(--color-ink)] list-none">
                      {item.q}
                      <span className="text-[var(--color-primary)] transition-transform group-open:rotate-45 text-lg leading-none shrink-0">+</span>
                    </summary>
                    <p className="px-5 pb-5 text-sm text-[var(--color-ink-variant)] leading-relaxed">{item.a}</p>
                  </details>
                ))}
              </div>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
