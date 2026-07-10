'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import {
  LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer
} from 'recharts';

const API_URL = 'http://127.0.0.1:3001';

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

function analyzeBP(s: number, d: number) {
  if (s < 90 || d < 60) return { status: 'Low', color: 'text-rose-700', bg: 'bg-rose-50', border: 'border-rose-200' };
  if (s <= 120 && d <= 80) return { status: 'Normal', color: 'text-green-700', bg: 'bg-green-50', border: 'border-green-200' };
  if (s <= 129 && d <= 80) return { status: 'Elevated', color: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' };
  if (s <= 139 || d <= 89) return { status: 'Stage 1', color: 'text-orange-700', bg: 'bg-orange-50', border: 'border-orange-200' };
  if (s <= 179 || d <= 119) return { status: 'Stage 2', color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' };
  return { status: 'Crisis', color: 'text-red-800', bg: 'bg-red-100', border: 'border-red-300' };
}

function analyzeHR(hr: number) {
  if (hr < 60) return { status: 'Low', color: 'text-rose-700', bg: 'bg-rose-50', border: 'border-rose-200' };
  if (hr <= 100) return { status: 'Normal', color: 'text-green-700', bg: 'bg-green-50', border: 'border-green-200' };
  if (hr <= 120) return { status: 'Elevated', color: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' };
  return { status: 'High', color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' };
}

function analyzeSugar(g: number) {
  if (g < 70) return { status: 'Low', color: 'text-rose-700', bg: 'bg-rose-50', border: 'border-rose-200' };
  if (g <= 100) return { status: 'Normal', color: 'text-green-700', bg: 'bg-green-50', border: 'border-green-200' };
  if (g <= 125) return { status: 'Prediabetic', color: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' };
  if (g <= 180) return { status: 'High', color: 'text-orange-700', bg: 'bg-orange-50', border: 'border-orange-200' };
  return { status: 'Very High', color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' };
}

function analyzeTemp(t: number) {
  if (t < 35) return { status: 'Hypothermia', color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' };
  if (t < 36) return { status: 'Low', color: 'text-rose-700', bg: 'bg-rose-50', border: 'border-rose-200' };
  if (t <= 37.2) return { status: 'Normal', color: 'text-green-700', bg: 'bg-green-50', border: 'border-green-200' };
  if (t <= 38) return { status: 'Mild Fever', color: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' };
  if (t <= 39) return { status: 'Fever', color: 'text-orange-700', bg: 'bg-orange-50', border: 'border-orange-200' };
  return { status: 'High Fever', color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' };
}

function analyzeSpO2(o: number) {
  if (o >= 95) return { status: 'Normal', color: 'text-green-700', bg: 'bg-green-50', border: 'border-green-200' };
  if (o >= 90) return { status: 'Mild Low', color: 'text-amber-700', bg: 'bg-amber-50', border: 'border-amber-200' };
  if (o >= 80) return { status: 'Low', color: 'text-orange-700', bg: 'bg-orange-50', border: 'border-orange-200' };
  return { status: 'Critical', color: 'text-red-700', bg: 'bg-red-50', border: 'border-red-200' };
}

export default function Home() {
  const router = useRouter();
  const [user, setUser] = useState<any>(null);
  const [medicines, setMedicines] = useState<Medicine[]>([]);
  const [medsLoading, setMedsLoading] = useState(true);
  const [vitals, setVitals] = useState<VitalSign[]>([]);
  const [vitalsLoading, setVitalsLoading] = useState(true);
  const [nextDose, setNextDose] = useState<{ name: string; time: string; remaining: string } | null>(null);
  const [chartType, setChartType] = useState('bp');

  useEffect(() => {
    const syncUser = () => {
      const token = localStorage.getItem('token');
      const userData = localStorage.getItem('user');
      setUser(token && userData ? JSON.parse(userData) : null);
    };
    syncUser();
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
        const res = await fetch(`${API_URL}/api/medicines`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (res.ok) { const d = await res.json(); setMedicines(d.medicines || []); }
      } catch (e) { console.error(e); } finally { setMedsLoading(false); }
    };

    const fetchVitals = async () => {
      try {
        const res = await fetch(`${API_URL}/api/vitals?limit=20`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (res.ok) { const d = await res.json(); setVitals(d.vitals || []); }
      } catch (e) { console.error(e); } finally { setVitalsLoading(false); }
    };

    if (isPatient) { fetchMeds(); fetchVitals(); }
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

  const today = new Date().toISOString().slice(0, 10);
  const latestVital = vitals[0];

  return (
    <div className="bg-background">
      {/* HEADER — consistent with other pages */}
      {isDoctor ? (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="text-center max-w-xl mx-auto">
            <h1 className="text-3xl font-bold text-text-main mb-3">Doctor Dashboard</h1>
            <p className="text-subtext mb-6">Manage your patient appointments and availability.</p>
            <Link href="/dashboard"><Button variant="primary">Go to Dashboard</Button></Link>
          </div>
        </div>
      ) : user ? (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
            <div>
              <h1 className="text-2xl sm:text-3xl font-bold text-text-main">
                Welcome, {user.name?.split(' ')[0] || 'User'}
              </h1>
              <p className="text-subtext text-sm mt-1">
                {new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
              </p>
            </div>
            <Link href="/dashboard">
              <Button variant="primary">Dashboard</Button>
            </Link>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
            {/* Latest Vitals */}
            <div className="lg:col-span-3">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-semibold text-text-main">Latest Vitals</h2>
                <Link href="/vitals" className="text-sm text-primary hover:underline">View all</Link>
              </div>

              {vitalsLoading ? (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
                  {[1,2,3].map(i => (
                    <div key={i} className="bg-white rounded-xl p-5 border border-gray-100 animate-pulse">
                      <div className="h-3 bg-gray-100 rounded w-12 mb-2" />
                      <div className="h-6 bg-gray-100 rounded w-16 mb-1" />
                      <div className="h-3 bg-gray-100 rounded w-8" />
                    </div>
                  ))}
                </div>
              ) : latestVital ? (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
                  {latestVital.blood_pressure_systolic && latestVital.blood_pressure_diastolic && (
                    <div className={`bg-white rounded-xl p-5 border ${analyzeBP(latestVital.blood_pressure_systolic, latestVital.blood_pressure_diastolic).border}`}>
                      <p className="text-xs text-gray-400 font-medium mb-1">Blood Pressure</p>
                      <p className="text-xl font-bold text-text-main">{latestVital.blood_pressure_systolic}/{latestVital.blood_pressure_diastolic}</p>
                      <span className={`inline-block mt-1.5 text-xs font-medium px-2 py-0.5 rounded ${analyzeBP(latestVital.blood_pressure_systolic, latestVital.blood_pressure_diastolic).bg} ${analyzeBP(latestVital.blood_pressure_systolic, latestVital.blood_pressure_diastolic).color}`}>
                        {analyzeBP(latestVital.blood_pressure_systolic, latestVital.blood_pressure_diastolic).status}
                      </span>
                    </div>
                  )}
                  {latestVital.heart_rate && (
                    <div className={`bg-white rounded-xl p-5 border ${analyzeHR(latestVital.heart_rate).border}`}>
                      <p className="text-xs text-gray-400 font-medium mb-1">Heart Rate</p>
                      <p className="text-xl font-bold text-text-main">{latestVital.heart_rate}</p>
                      <span className={`inline-block mt-1.5 text-xs font-medium px-2 py-0.5 rounded ${analyzeHR(latestVital.heart_rate).bg} ${analyzeHR(latestVital.heart_rate).color}`}>
                        {analyzeHR(latestVital.heart_rate).status}
                      </span>
                    </div>
                  )}
                  {latestVital.blood_sugar && (
                    <div className={`bg-white rounded-xl p-5 border ${analyzeSugar(latestVital.blood_sugar).border}`}>
                      <p className="text-xs text-gray-400 font-medium mb-1">Blood Sugar</p>
                      <p className="text-xl font-bold text-text-main">{Math.round(latestVital.blood_sugar)}</p>
                      <span className={`inline-block mt-1.5 text-xs font-medium px-2 py-0.5 rounded ${analyzeSugar(latestVital.blood_sugar).bg} ${analyzeSugar(latestVital.blood_sugar).color}`}>
                        {analyzeSugar(latestVital.blood_sugar).status}
                      </span>
                    </div>
                  )}
                  {latestVital.temperature && (
                    <div className={`bg-white rounded-xl p-5 border ${analyzeTemp(latestVital.temperature).border}`}>
                      <p className="text-xs text-gray-400 font-medium mb-1">Temperature</p>
                      <p className="text-xl font-bold text-text-main">{latestVital.temperature.toFixed(1)}°C</p>
                      <span className={`inline-block mt-1.5 text-xs font-medium px-2 py-0.5 rounded ${analyzeTemp(latestVital.temperature).bg} ${analyzeTemp(latestVital.temperature).color}`}>
                        {analyzeTemp(latestVital.temperature).status}
                      </span>
                    </div>
                  )}
                  {latestVital.oxygen_saturation && (
                    <div className={`bg-white rounded-xl p-5 border ${analyzeSpO2(latestVital.oxygen_saturation).border}`}>
                      <p className="text-xs text-gray-400 font-medium mb-1">SpO2</p>
                      <p className="text-xl font-bold text-text-main">{latestVital.oxygen_saturation}%</p>
                      <span className={`inline-block mt-1.5 text-xs font-medium px-2 py-0.5 rounded ${analyzeSpO2(latestVital.oxygen_saturation).bg} ${analyzeSpO2(latestVital.oxygen_saturation).color}`}>
                        {analyzeSpO2(latestVital.oxygen_saturation).status}
                      </span>
                    </div>
                  )}
                  {latestVital.weight && (
                    <div className="bg-white rounded-xl p-5 border border-gray-100">
                      <p className="text-xs text-gray-400 font-medium mb-1">Weight</p>
                      <p className="text-xl font-bold text-text-main">{latestVital.weight.toFixed(1)} kg</p>
                      <span className="inline-block mt-1.5 text-xs font-medium px-2 py-0.5 rounded bg-blue-50 text-blue-700">Recorded</span>
                    </div>
                  )}
                </div>
              ) : (
                <Card className="p-8 text-center">
                  <p className="text-subtext mb-4">No vital signs recorded yet</p>
                  <Link href="/vitals"><Button>Record Your First Reading</Button></Link>
                </Card>
              )}

              {/* Trend Chart */}
              {vitals.length > 1 && (
                <div className="bg-white rounded-xl p-5 border border-gray-100 mt-6">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-sm font-semibold text-gray-900 uppercase tracking-wider">Trends</h3>
                    <select value={chartType} onChange={e => setChartType(e.target.value)}
                      className="text-xs border rounded-md px-2 py-1 text-gray-600">
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
                      <LineChart data={[...vitals].reverse().map((v, i) => ({
                        name: `#${i + 1}`,
                        systolic: v.blood_pressure_systolic,
                        diastolic: v.blood_pressure_diastolic,
                        heartRate: v.heart_rate,
                        bloodSugar: v.blood_sugar,
                        temperature: v.temperature,
                        oxygenSaturation: v.oxygen_saturation,
                        weight: v.weight,
                      }))}>
                        <XAxis dataKey="name" tick={{ fontSize: 10 }} />
                        <YAxis tick={{ fontSize: 10 }} />
                        <Tooltip />
                        {chartType === 'bp' && <>
                          <Line type="monotone" dataKey="systolic" stroke="#ef4444" name="Systolic" strokeWidth={2} dot={false} />
                          <Line type="monotone" dataKey="diastolic" stroke="#3b82f6" name="Diastolic" strokeWidth={2} dot={false} />
                        </>}
                        {chartType === 'hr' && <Line type="monotone" dataKey="heartRate" stroke="#8b5cf6" name="Heart Rate" strokeWidth={2} dot={false} />}
                        {chartType === 'sugar' && <Line type="monotone" dataKey="bloodSugar" stroke="#f59e0b" name="Blood Sugar" strokeWidth={2} dot={false} />}
                        {chartType === 'temp' && <Line type="monotone" dataKey="temperature" stroke="#ec4899" name="Temperature" strokeWidth={2} dot={false} />}
                        {chartType === 'spo2' && <Line type="monotone" dataKey="oxygenSaturation" stroke="#06b6d4" name="SpO2" strokeWidth={2} dot={false} />}
                        {chartType === 'weight' && <Line type="monotone" dataKey="weight" stroke="#10b981" name="Weight" strokeWidth={2} dot={false} />}
                      </LineChart>
                    </ResponsiveContainer>
                  </div>
                </div>
              )}

              {/* Quick links */}
              <div className="grid grid-cols-3 gap-4 mt-6">
                <Link href="/appointments">
                  <div className="bg-white rounded-xl p-4 border border-gray-100 hover:border-gray-200 transition-colors text-center">
                    <p className="text-sm font-medium text-text-main">Appointments</p>
                  </div>
                </Link>
                <Link href="/reports">
                  <div className="bg-white rounded-xl p-4 border border-gray-100 hover:border-gray-200 transition-colors text-center">
                    <p className="text-sm font-medium text-text-main">Reports</p>
                  </div>
                </Link>
                <Link href="/medicines">
                  <div className="bg-white rounded-xl p-4 border border-gray-100 hover:border-gray-200 transition-colors text-center">
                    <p className="text-sm font-medium text-text-main">Medicines</p>
                  </div>
                </Link>
              </div>
            </div>

            {/* Today's Medicines */}
            <div className="lg:col-span-2">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-semibold text-text-main">Today's Medicines</h2>
                <Link href="/medicines" className="text-sm text-primary hover:underline">Manage</Link>
              </div>

              {nextDose && (
                <div className="bg-white rounded-xl p-5 border border-green-200 mb-4">
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 bg-green-50 rounded-lg flex items-center justify-center shrink-0">
                      <span className="text-green-700 text-lg">&#9679;</span>
                    </div>
                    <div>
                      <p className="text-xs font-semibold text-green-700 uppercase tracking-wider">Next dose</p>
                      <p className="text-sm font-semibold text-text-main mt-0.5">{nextDose.name}</p>
                      <p className="text-xs text-subtext mt-0.5">{nextDose.time} &mdash; <span className="text-green-700 font-medium">{nextDose.remaining} left</span></p>
                    </div>
                  </div>
                </div>
              )}

              {medsLoading ? (
                <div className="space-y-3">
                  {[1,2].map(i => (
                    <div key={i} className="bg-white rounded-xl p-5 border border-gray-100 animate-pulse">
                      <div className="h-4 bg-gray-100 rounded w-24 mb-2" />
                      <div className="h-3 bg-gray-100 rounded w-16" />
                    </div>
                  ))}
                </div>
              ) : medicines.filter(m => !m.end_date || m.end_date >= today).length > 0 ? (
                <div className="space-y-3">
                  {medicines.filter(m => !m.end_date || m.end_date >= today).map(med => {
                    const times = parseTimes(med.taking_times);
                    const curMin = new Date().getHours() * 60 + new Date().getMinutes();
                    return (
                      <div key={med.id} className="bg-white rounded-xl p-5 border border-gray-100">
                        <div className="flex items-start gap-3">
                          <div className="w-9 h-9 bg-blue-50 rounded-lg flex items-center justify-center shrink-0 mt-0.5">
                            <span className="text-primary text-sm font-bold">Rx</span>
                          </div>
                          <div>
                            <p className="text-sm font-semibold text-text-main">{med.name}</p>
                            <p className="text-xs text-subtext mb-2">{med.dosage}</p>
                            {times.length > 0 && (
                              <div className="flex flex-wrap gap-1.5">
                                {times.map((t, i) => {
                                  const [h, m] = t.split(':').map(Number);
                                  const isPast = h * 60 + m < curMin;
                                  return (
                                    <span key={i} className={`inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium ${
                                      isPast ? 'bg-gray-50 text-gray-300 line-through' : 'bg-blue-50 text-blue-700'
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
                  <p className="text-subtext mb-4">No medicines added yet</p>
                  <Link href="/medicines"><Button>Add Medicines</Button></Link>
                </Card>
              )}
            </div>
          </div>
        </div>
      ) : (
        /* PUBLIC LANDING PAGE — non-logged-in */
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-20 pb-16 text-center">
          <p className="text-sm text-primary font-medium mb-3">Secure & Private</p>
          <h1 className="text-4xl md:text-5xl font-bold text-text-main mb-4">
            Your Personal Digital <span className="text-primary">Health Store</span>
          </h1>
          <p className="text-subtext mb-8 max-w-lg mx-auto">
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
          <section className="py-24 bg-white">
            <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
              <div className="text-center mb-16">
                <h2 className="text-2xl font-bold text-text-main mb-3">Everything You Need</h2>
                <p className="text-subtext">Tools to manage your health efficiently and securely.</p>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <Card>
                  <h3 className="text-lg font-semibold text-text-main mb-2">Upload Records</h3>
                  <p className="text-sm text-subtext">Upload and organize your lab results, prescriptions, and medical history.</p>
                </Card>
                <Card>
                  <h3 className="text-lg font-semibold text-text-main mb-2">Track Health</h3>
                  <p className="text-sm text-subtext">Monitor vitals and manage appointments from one place.</p>
                </Card>
                <Card>
                  <h3 className="text-lg font-semibold text-text-main mb-2">Secure Sharing</h3>
                  <p className="text-sm text-subtext">Share medical records with specialists via encrypted links.</p>
                </Card>
              </div>
            </div>
          </section>

          <section className="py-20 bg-background text-center">
            <div className="max-w-md mx-auto px-4">
              <h2 className="text-2xl font-bold text-text-main mb-4">Ready to Take Control?</h2>
              <p className="text-subtext mb-8">Join others who trust MediStore to securely manage their medical information.</p>
              <Link href="/auth/register"><Button variant="primary" className="text-base px-6 py-2.5">Create Free Account</Button></Link>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
