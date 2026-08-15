'use client';

import { useEffect, useState, useMemo, useCallback } from 'react';
import Link from 'next/link';
import { Activity, CalendarDays, FileText, Pill } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { StatusChip } from '@/components/ui/status-chip';
import { RangeBar } from '@/components/ui/range-bar';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/ui/empty-state';
import {
  analyzeBP, analyzeHR, analyzeSugar, analyzeTemp, analyzeSpO2,
  type VitalBand,
} from '@/lib/status';
import {
  LineChart, Line, XAxis, YAxis, Tooltip, Legend, ReferenceArea, ResponsiveContainer,
} from 'recharts';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

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

interface SessionUser {
  id: string;
  name: string;
  email: string;
  role: string;
}

function VitalTile({
  label, value, unit, analysis,
}: {
  label: string;
  value: string;
  unit: string;
  analysis: VitalBand;
}) {
  return (
    <Card className="p-lg">
      <p className="text-xs font-medium text-on-surface-variant mb-1">{label}</p>
      <p className="text-2xl font-display font-semibold text-on-surface tabular-nums">
        {value} <span className="text-sm font-normal text-on-surface-variant">{unit}</span>
      </p>
      <StatusChip level={analysis.level} label={analysis.label} trend={analysis.trend} className="mt-1.5" />
      <RangeBar
        min={analysis.scale.min}
        max={analysis.scale.max}
        bandStart={analysis.band.low}
        bandEnd={analysis.band.high}
        value={Number(analysis.band.low === analysis.band.high ? analysis.band.low : value) || 0}
        className="mt-md"
      />
    </Card>
  );
}

/** The one dose still to come today, judged on the patient's own clock. */
function computeNextDose(
  medicines: Medicine[],
  now: Date,
): { name: string; time: string; remaining: string } | null {
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

  if (!closest) return null;
  const hrs = Math.floor(closest.diff / 60), mins = closest.diff % 60;
  return {
    name: closest.name,
    time: closest.time,
    remaining: hrs > 0 ? `${hrs}h ${mins}m` : `${mins}m`,
  };
}

export default function Home() {
  const [user, setUser] = useState<SessionUser | null>(() => {
    if (typeof window === 'undefined') return null;
    try {
      const u = localStorage.getItem('user');
      return u ? (JSON.parse(u) as SessionUser) : null;
    } catch { return null; }
  });
  const [medicines, setMedicines] = useState<Medicine[] | null>(null);
  const [vitals, setVitals] = useState<VitalSign[] | null>(null);
  const [now, setNow] = useState(() => new Date());
  const [chartType, setChartType] = useState('bp');

  useEffect(() => {
    const sync = () => {
      try {
        const u = localStorage.getItem('user');
        setUser(u ? (JSON.parse(u) as SessionUser) : null);
      } catch { setUser(null); }
    };
    window.addEventListener('localStorageUpdated', sync);
    window.addEventListener('storage', sync);
    return () => {
      window.removeEventListener('localStorageUpdated', sync);
      window.removeEventListener('storage', sync);
    };
  }, []);

  // Recompute "next dose" every 30s so the countdown stays honest.
  useEffect(() => {
    const i = setInterval(() => setNow(new Date()), 30000);
    return () => clearInterval(i);
  }, []);

  const isPatient = user !== null && user.role !== 'DOCTOR';
  const isDoctor = user?.role === 'DOCTOR';

  useEffect(() => {
    const token = typeof window !== 'undefined' ? localStorage.getItem('token') : null;
    if (!token || !isPatient) return;

    let cancelled = false;

    const fetchMeds = async () => {
      try {
        const res = await fetch(`${API_URL}/api/medicines`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (res.ok) { const d = await res.json(); if (!cancelled) setMedicines(d.medicines || []); }
      } catch (e) { console.error(e); if (!cancelled) setMedicines([]); }
    };

    const fetchVitals = async () => {
      try {
        const res = await fetch(`${API_URL}/api/vitals?limit=20`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (res.ok) { const d = await res.json(); if (!cancelled) setVitals(d.vitals || []); }
      } catch (e) { console.error(e); if (!cancelled) setVitals([]); }
    };

    fetchMeds();
    fetchVitals();
    return () => { cancelled = true; };
  }, [isPatient]);

  const nextDose = useMemo(() => computeNextDose(medicines ?? [], now), [medicines, now]);

  const parseTimes = useCallback((tt?: string): string[] => {
    if (!tt) return [];
    try { return JSON.parse(tt); } catch { return []; }
  }, []);

  const today = new Date().toISOString().slice(0, 10);
  const latestVital = vitals?.[0];
  const medsLoading = medicines === null;
  const vitalsLoading = vitals === null;

  // Normal band shaded behind the trend line — the third and last home of the
  // range bar grammar.
  const chartBand: { low: number; high: number } | null = {
    bp: { low: 90, high: 120 },
    hr: { low: 60, high: 100 },
    sugar: { low: 70, high: 100 },
    temp: { low: 36, high: 37.2 },
    spo2: { low: 95, high: 100 },
    weight: { low: 45, high: 90 },
  }[chartType] ?? null;

  const chartData = [...(vitals ?? [])].reverse().map((v) => ({
    name: '',
    systolic: v.blood_pressure_systolic,
    diastolic: v.blood_pressure_diastolic,
    heartRate: v.heart_rate,
    bloodSugar: v.blood_sugar,
    temperature: v.temperature,
    oxygenSaturation: v.oxygen_saturation,
    weight: v.weight,
  }));

  return (
    <div className="bg-surface">
      {/* HEADER — consistent with other pages */}
      {isDoctor ? (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="text-center max-w-xl mx-auto">
            <h1 className="text-3xl font-display font-bold text-on-surface mb-3">Doctor Dashboard</h1>
            <p className="text-on-surface-variant mb-6">Manage your patient appointments and availability.</p>
            <Link href="/dashboard"><Button>Go to Dashboard</Button></Link>
          </div>
        </div>
      ) : user ? (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
            <div>
              <h1 className="text-2xl sm:text-3xl font-display font-bold text-on-surface">
                Welcome, {user.name?.split(' ')[0] || 'User'}
              </h1>
              <p className="text-on-surface-variant text-sm mt-1">
                {new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
              </p>
            </div>
            <Link href="/dashboard">
              <Button variant="secondary">Go to dashboard</Button>
            </Link>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
            {/* Latest Vitals */}
            <div className="lg:col-span-3">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-display font-semibold text-on-surface">Latest Vitals</h2>
                <Link href="/vitals" className="text-sm text-primary hover:underline">View all</Link>
              </div>

              {vitalsLoading ? (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
                  {[1, 2, 3].map((i) => (
                    <Card key={i} className="p-lg">
                      <Skeleton className="h-3 w-12 mb-2" />
                      <Skeleton className="h-6 w-16 mb-1" />
                      <Skeleton className="h-3 w-8" />
                    </Card>
                  ))}
                </div>
              ) : latestVital ? (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
                  {latestVital.blood_pressure_systolic && latestVital.blood_pressure_diastolic && (
                    <VitalTile
                      label="Blood Pressure"
                      value={`${latestVital.blood_pressure_systolic}/${latestVital.blood_pressure_diastolic}`}
                      unit="mmHg"
                      analysis={analyzeBP(latestVital.blood_pressure_systolic, latestVital.blood_pressure_diastolic)}
                    />
                  )}
                  {latestVital.heart_rate && (
                    <VitalTile
                      label="Heart Rate"
                      value={String(latestVital.heart_rate)}
                      unit="bpm"
                      analysis={analyzeHR(latestVital.heart_rate)}
                    />
                  )}
                  {latestVital.blood_sugar && (
                    <VitalTile
                      label="Blood Sugar"
                      value={String(Math.round(latestVital.blood_sugar))}
                      unit="mg/dL"
                      analysis={analyzeSugar(latestVital.blood_sugar)}
                    />
                  )}
                  {latestVital.temperature && (
                    <VitalTile
                      label="Temperature"
                      value={latestVital.temperature.toFixed(1)}
                      unit="°C"
                      analysis={analyzeTemp(latestVital.temperature)}
                    />
                  )}
                  {latestVital.oxygen_saturation && (
                    <VitalTile
                      label="SpO2"
                      value={String(latestVital.oxygen_saturation)}
                      unit="%"
                      analysis={analyzeSpO2(latestVital.oxygen_saturation)}
                    />
                  )}
                  {latestVital.weight && (
                    <VitalTile
                      label="Weight"
                      value={latestVital.weight.toFixed(1)}
                      unit="kg"
                      analysis={{ level: 'ok', label: 'Recorded', band: { low: 45, high: 90 }, scale: { min: 30, max: 150 } }}
                    />
                  )}
                </div>
              ) : (
                <Card className="p-lg">
                  <EmptyState
                    icon={Activity}
                    title="No vital signs recorded yet"
                    description="The first reading gets a range bar, a band name and a trend to follow."
                    action={<Link href="/vitals"><Button>Record your first reading</Button></Link>}
                  />
                </Card>
              )}

              {/* Trend Chart */}
              {(vitals?.length ?? 0) > 1 && (
                <Card className="p-lg mt-6">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-xs font-semibold text-on-surface uppercase tracking-wider">Trends</h3>
                    <select
                      value={chartType}
                      onChange={(e) => setChartType(e.target.value)}
                      className="text-xs border border-outline rounded-sm px-2 py-1 text-on-surface-variant bg-surface-card"
                      aria-label="Choose a metric"
                    >
                      <option value="bp">Blood Pressure</option>
                      <option value="hr">Heart Rate</option>
                      <option value="sugar">Blood Sugar</option>
                      <option value="temp">Temperature</option>
                      <option value="spo2">SpO2</option>
                      <option value="weight">Weight</option>
                    </select>
                  </div>
                  <div style={{ height: 200 }}>
                    <ResponsiveContainer width="100%" height="100%">
                      <LineChart data={chartData}>
                        <XAxis dataKey="name" tick={{ fontSize: 10, fill: 'var(--color-on-surface-variant)' }} tickLine={false} axisLine={{ stroke: 'var(--color-outline)' }} />
                        <YAxis tick={{ fontSize: 10, fill: 'var(--color-on-surface-variant)' }} tickLine={false} axisLine={false} width={36} />
                        <Tooltip contentStyle={{ background: 'var(--color-surface-card)', border: '1px solid var(--color-outline)', borderRadius: 8, fontSize: 12 }} labelStyle={{ color: 'var(--color-on-surface-variant)' }} />
                        {chartBand && (
                          <ReferenceArea y1={chartBand.low} y2={chartBand.high} fill="var(--color-primary)" fillOpacity={0.08} />
                        )}
                        {chartType === 'bp' && <>
                          <Legend wrapperStyle={{ fontSize: 12, color: 'var(--color-on-surface-variant)' }} />
                          <Line type="monotone" dataKey="systolic" stroke="var(--color-series-1)" name="Systolic" strokeWidth={2} dot={false} />
                          <Line type="monotone" dataKey="diastolic" stroke="var(--color-series-2)" name="Diastolic" strokeWidth={2} dot={false} />
                        </>}
                        {chartType === 'hr' && <Line type="monotone" dataKey="heartRate" stroke="var(--color-series-1)" name="Heart Rate" strokeWidth={2} dot={false} />}
                        {chartType === 'sugar' && <Line type="monotone" dataKey="bloodSugar" stroke="var(--color-series-1)" name="Blood Sugar" strokeWidth={2} dot={false} />}
                        {chartType === 'temp' && <Line type="monotone" dataKey="temperature" stroke="var(--color-series-1)" name="Temperature" strokeWidth={2} dot={false} />}
                        {chartType === 'spo2' && <Line type="monotone" dataKey="oxygenSaturation" stroke="var(--color-series-1)" name="SpO2" strokeWidth={2} dot={false} />}
                        {chartType === 'weight' && <Line type="monotone" dataKey="weight" stroke="var(--color-series-1)" name="Weight" strokeWidth={2} dot={false} />}
                      </LineChart>
                    </ResponsiveContainer>
                  </div>
                </Card>
              )}

              {/* Quick links */}
              <div className="grid grid-cols-3 gap-4 mt-6">
                <Link href="/appointments">
                  <Card className="p-lg text-center hover:border-outline transition-colors">
                    <CalendarDays className="w-5 h-5 text-primary mx-auto mb-1.5" />
                    <p className="text-sm font-medium text-on-surface">Appointments</p>
                  </Card>
                </Link>
                <Link href="/reports">
                  <Card className="p-lg text-center hover:border-outline transition-colors">
                    <FileText className="w-5 h-5 text-primary mx-auto mb-1.5" />
                    <p className="text-sm font-medium text-on-surface">Reports</p>
                  </Card>
                </Link>
                <Link href="/medicines">
                  <Card className="p-lg text-center hover:border-outline transition-colors">
                    <Pill className="w-5 h-5 text-primary mx-auto mb-1.5" />
                    <p className="text-sm font-medium text-on-surface">Medicines</p>
                  </Card>
                </Link>
              </div>
            </div>

            {/* Today's Medicines */}
            <div className="lg:col-span-2">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-display font-semibold text-on-surface">Today&apos;s Medicines</h2>
                <Link href="/medicines" className="text-sm text-primary hover:underline">Manage</Link>
              </div>

              {nextDose && (
                <div className="bg-ok-container border border-ok/30 rounded-md p-lg mb-lg">
                  <div className="flex items-start gap-sm">
                    <div className="w-10 h-10 bg-ok-container rounded-sm flex items-center justify-center shrink-0">
                      <Pill className="w-5 h-5 text-ok" />
                    </div>
                    <div>
                      <p className="text-xs font-semibold text-ok uppercase tracking-wider">Next dose</p>
                      <p className="text-sm font-semibold text-on-surface mt-0.5">{nextDose.name}</p>
                      <p className="text-xs text-on-surface-variant mt-0.5 tabular-nums">
                        {nextDose.time} — <span className="text-ok font-medium">{nextDose.remaining} left</span>
                      </p>
                    </div>
                  </div>
                </div>
              )}

              {medsLoading ? (
                <div className="space-y-3">
                  {[1, 2].map((i) => (
                    <Card key={i} className="p-lg">
                      <Skeleton className="h-4 w-24 mb-2" />
                      <Skeleton className="h-3 w-16" />
                    </Card>
                  ))}
                </div>
              ) : medicines && medicines.filter((m) => !m.end_date || m.end_date >= today).length > 0 ? (
                <div className="space-y-3">
                  {medicines.filter((m) => !m.end_date || m.end_date >= today).map((med) => {
                    const times = parseTimes(med.taking_times);
                    const curMin = now.getHours() * 60 + now.getMinutes();
                    return (
                      <Card key={med.id} className="p-lg">
                        <div className="flex items-start gap-sm">
                          <div className="w-9 h-9 bg-primary/10 rounded-sm flex items-center justify-center shrink-0 mt-0.5">
                            <Pill className="w-4 h-4 text-primary" />
                          </div>
                          <div>
                            <p className="text-sm font-semibold text-on-surface">{med.name}</p>
                            <p className="text-xs text-on-surface-variant mb-2">{med.dosage}</p>
                            {times.length > 0 && (
                              <div className="flex flex-wrap gap-1.5">
                                {times.map((t, i) => {
                                  const [h, m] = t.split(':').map(Number);
                                  const isPast = h * 60 + m < curMin;
                                  return (
                                    <span key={i} className={`inline-flex items-center px-2 py-0.5 rounded-sm text-xs font-medium tabular-nums ${
                                      isPast ? 'bg-surface text-on-surface-variant/40 line-through' : 'bg-primary/10 text-primary'
                                    }`}>
                                      {t}
                                    </span>
                                  );
                                })}
                              </div>
                            )}
                          </div>
                        </div>
                      </Card>
                    );
                  })}
                </div>
              ) : (
                <Card className="p-lg">
                  <EmptyState
                    icon={Pill}
                    title="No medicines tracked yet"
                    description="Add your medicines and get a daily dose plan with reminders."
                    action={<Link href="/medicines"><Button>Add medicines</Button></Link>}
                  />
                </Card>
              )}
            </div>
          </div>
        </div>
      ) : (
        /* PUBLIC LANDING PAGE — non-logged-in */
        <>
          <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-20 pb-24">
            <div className="grid lg:grid-cols-2 gap-12 items-center">
              <div>
                <p className="text-xs font-semibold uppercase tracking-wider text-primary mb-4">
                  Your health record, in one place
                </p>
                <h1 className="text-4xl md:text-5xl font-display font-bold text-on-surface tracking-tight mb-6">
                  Know what your <span className="text-primary">numbers mean</span>
                </h1>
                <p className="text-lg text-on-surface-variant mb-8 max-w-lg leading-relaxed">
                  MediStore keeps your reports, medicines and vitals together — and
                  judges every reading against the range your doctor works with. A
                  number is never just a number.
                </p>
                <div className="flex flex-wrap items-center gap-3">
                  <Link href="/auth/register"><Button size="md">Get started</Button></Link>
                  <Link href="/auth/login"><Button variant="secondary">Log in</Button></Link>
                </div>
              </div>

              {/* The range-bar grammar, as the artifact */}
              <Card className="p-xl">
                <div className="flex items-center justify-between mb-lg">
                  <p className="text-xs font-semibold uppercase tracking-wider text-on-surface-variant">
                    How MediStore reads a reading
                  </p>
                  <span className="text-xs text-on-surface-variant">Example</span>
                </div>
                <div className="flex items-baseline justify-between mb-md">
                  <p className="text-lg font-display font-semibold text-on-surface">Blood pressure</p>
                  <p className="text-2xl font-display font-semibold text-on-surface tabular-nums">
                    128/82 <span className="text-sm font-normal text-on-surface-variant">mmHg</span>
                  </p>
                </div>
                <RangeBar
                  min={40}
                  max={240}
                  bandStart={90}
                  bandEnd={120}
                  value={128}
                  lowLabel="90"
                  highLabel="120"
                  className="mb-md"
                />
                <div className="flex items-center gap-sm">
                  <StatusChip level="caution" label="Elevated" trend="up" />
                  <p className="text-xs text-on-surface-variant">
                    Position first, colour second — the marker sits above the normal band.
                  </p>
                </div>
              </Card>
            </div>
          </section>

          {/* The problems this product actually solves */}
          <section className="py-20 bg-surface-card border-y border-outline">
            <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
              <h2 className="text-2xl md:text-3xl font-display font-bold text-on-surface text-center mb-14">
                A health record should answer the questions a doctor asks
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div>
                  <h3 className="font-display font-semibold text-on-surface mb-2">A reading without its reference</h3>
                  <p className="text-sm text-on-surface-variant leading-relaxed">
                    128/82 means nothing until you know where normal is. MediStore shows the
                    band every reading is judged against — never colour alone.
                  </p>
                </div>
                <div>
                  <h3 className="font-display font-semibold text-on-surface mb-2">Reports that live in a drawer</h3>
                  <p className="text-sm text-on-surface-variant leading-relaxed">
                    Paper gets lost, and the hospital copy stays at the hospital. Your reports,
                    medicines and vitals live in one record, at hand when someone asks.
                  </p>
                </div>
                <div>
                  <h3 className="font-display font-semibold text-on-surface mb-2">Sharing by photocopy</h3>
                  <p className="text-sm text-on-surface-variant leading-relaxed">
                    Sending records to a specialist is a fragile chain of scans and screenshots.
                    One expiring link does it — and you revoke it whenever you want.
                  </p>
                </div>
              </div>
            </div>
          </section>

          {/* What the product does — every claim maps to a real screen */}
          <section className="py-20">
            <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <Card>
                  <h3 className="text-lg font-display font-semibold text-on-surface mb-2">Range bars on every reading</h3>
                  <p className="text-sm text-on-surface-variant">
                    Vitals, lab findings and trends all show the normal band and where your
                    value sits on it.
                  </p>
                </Card>
                <Card>
                  <h3 className="text-lg font-display font-semibold text-on-surface mb-2">One record, always at hand</h3>
                  <p className="text-sm text-on-surface-variant">
                    Lab reports with OCR and AI summaries, medicines with dose reminders,
                    appointments, and an emergency card.
                  </p>
                </Card>
                <Card>
                  <h3 className="text-lg font-display font-semibold text-on-surface mb-2">Sharing that expires</h3>
                  <p className="text-sm text-on-surface-variant">
                    Share a report with a specialist via a link that expires — and see who
                    has kept a copy, and revoke it.
                  </p>
                </Card>
              </div>
            </div>
          </section>

          {/* CTA */}
          <section className="py-20 bg-surface-card border-t border-outline text-center">
            <div className="max-w-md mx-auto px-4">
              <h2 className="text-2xl font-display font-bold text-on-surface mb-4">
                Start with your first reading
              </h2>
              <p className="text-on-surface-variant mb-8">
                Free to use. Your records are locked behind your account and leave
                only through links you control.
              </p>
              <div className="flex justify-center gap-3">
                <Link href="/auth/register"><Button>Create free account</Button></Link>
                <Link href="/auth/login"><Button variant="secondary">Log in</Button></Link>
              </div>
            </div>
          </section>
        </>
      )}
    </div>
  );
}