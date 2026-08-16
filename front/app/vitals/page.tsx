'use client';

import { useEffect, useState } from 'react';
import { apiFetch } from '@/lib/api';
import { useRouter } from 'next/navigation';
import { Activity, Mic, X, Plus, Info, Thermometer, Heart, Droplets, Wind, Scale, Stethoscope } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { StatusChip } from '@/components/ui/status-chip';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/ui/empty-state';
import {
  analyzeBP, analyzeHR, analyzeSugar, analyzeTemp, analyzeSpO2,
  type VitalBand,
} from '@/lib/status';
import {
  LineChart, Line, XAxis, YAxis, Tooltip, Legend, ReferenceArea, ResponsiveContainer,
} from 'recharts';
import { useSpeechRecognition } from '@/lib/useSpeechRecognition';
import { formatServerDate, formatServerDateTime } from '@/lib/datetime';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

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

/* ---- Patient-friendly vital sign information ---- */
const VITAL_INFO: Record<string, {
  icon: typeof Heart;
  title: string;
  fullName: string;
  unit: string;
  normalRange: string;
  whatItMeasures: string;
  whatIsNormal: string;
  whatItMeans: string[];
  whenToSeekHelp: string;
  tips: string;
}> = {
  bp: {
    icon: Stethoscope,
    title: 'Blood Pressure',
    fullName: 'Blood Pressure (Systolic / Diastolic)',
    unit: 'mmHg',
    normalRange: 'Below 120/80',
    whatItMeasures: 'The force of blood pushing against your artery walls as your heart pumps.',
    whatIsNormal: 'Normal blood pressure is below 120/80 mmHg. The top number (systolic) is the pressure when your heart beats; the bottom number (diastolic) is the pressure when your heart rests between beats.',
    whatItMeans: [
      'Systolic (top number): Pressure in arteries when your heart beats and pushes blood out.',
      'Diastolic (bottom number): Pressure in arteries when your heart rests between beats.',
      'Both numbers matter. A reading of 130/85 means the systolic is 130 and diastolic is 85.',
    ],
    whenToSeekHelp: 'Seek immediate care if your reading is above 180/120 or below 90/60, especially with headache, chest pain, or vision changes.',
    tips: 'Measure at the same time daily. Sit quietly for 5 minutes before measuring. Keep your arm at heart level.',
  },
  hr: {
    icon: Heart,
    title: 'Heart Rate',
    fullName: 'Heart Rate (Pulse)',
    unit: 'bpm',
    normalRange: '60–100 bpm at rest',
    whatItMeasures: 'How many times your heart beats per minute while at rest.',
    whatIsNormal: 'A resting heart rate of 60–100 bpm is normal for adults. Athletes may have rates as low as 40 bpm. Higher isn\'t always worse — it depends on your fitness level.',
    whatItMeans: [
      'Resting heart rate is measured when you\'re calm and still.',
      'A lower resting rate usually means better cardiovascular fitness.',
      'Heart rate naturally rises with exercise, stress, caffeine, or illness.',
    ],
    whenToSeekHelp: 'See a doctor if your resting heart rate is consistently above 100 bpm or below 50 bpm, or if you feel dizzy or faint.',
    tips: 'Measure first thing in the morning before getting out of bed for the most accurate resting rate.',
  },
  weight: {
    icon: Scale,
    title: 'Weight',
    fullName: 'Body Weight',
    unit: 'kg',
    normalRange: 'Varies by height',
    whatItMeasures: 'Your total body mass. Track trends over time rather than day-to-day changes.',
    whatIsNormal: 'A healthy weight depends on your height, age, and body composition. Focus on trends — gradual changes matter more than daily fluctuations.',
    whatItMeans: [
      'Weight can fluctuate 1–2 kg daily due to water, food, and activity.',
      'Track weekly averages for a more accurate picture.',
      'Sudden unexplained weight changes (5+ kg in a month) should be discussed with your doctor.',
    ],
    whenToSeekHelp: 'Consult your doctor if you gain or lose more than 5 kg without changing diet or exercise.',
    tips: 'Weigh yourself at the same time each morning, after using the bathroom and before eating.',
  },
  sugar: {
    icon: Droplets,
    title: 'Blood Sugar',
    fullName: 'Blood Glucose Level',
    unit: 'mg/dL',
    normalRange: '70–100 mg/dL (fasting)',
    whatItMeasures: 'The amount of sugar (glucose) in your blood. Your body uses glucose as its main source of energy.',
    whatIsNormal: 'Fasting blood sugar should be 70–100 mg/dL. After meals, it can rise to 120–140 mg/dL and return to normal within 2 hours.',
    whatItMeans: [
      'Fasting blood sugar: measured after not eating for at least 8 hours.',
      'Prediabetes: 100–125 mg/dL (fasting) — a warning sign to change habits.',
      'Diabetes: 126+ mg/dL (fasting) on two separate tests.',
    ],
    whenToSeekHelp: 'Seek care if blood sugar is below 54 mg/dL (hypoglycemia) or above 300 mg/dL (hyperglycemia).',
    tips: 'Avoid eating or drinking (except water) for 8 hours before a fasting test. Stay hydrated.',
  },
  temp: {
    icon: Thermometer,
    title: 'Temperature',
    fullName: 'Body Temperature',
    unit: '°C / °F',
    normalRange: '36.1–37.2°C (97.0–99.0°F)',
    whatItMeasures: 'Your body\'s internal temperature. It\'s a key indicator of infection or illness.',
    whatIsNormal: 'Normal body temperature ranges from 36.1°C to 37.2°C (97.0°F to 99.0°F). It\'s slightly lower in the morning and higher in the evening.',
    whatItMeans: [
      'Fever: Temperature above 38°C (100.4°F) often means your body is fighting an infection.',
      'Hypothermia: Temperature below 35°C (95°F) is dangerously low.',
      'Temperature varies by measurement method (oral, ear, forehead).',
    ],
    whenToSeekHelp: 'Seek care for fever above 39.4°C (103°F), or any fever lasting more than 3 days in adults.',
    tips: 'Oral thermometers are most accurate. Wait 30 minutes after eating or drinking before measuring.',
  },
  spo2: {
    icon: Wind,
    title: 'Oxygen Saturation',
    fullName: 'Blood Oxygen Saturation (SpO2)',
    unit: '%',
    normalRange: '95–100%',
    whatItMeasures: 'The percentage of oxygen in your blood. It shows how well your lungs are delivering oxygen to your body.',
    whatIsNormal: 'A normal SpO2 reading is 95–100%. Below 90% is considered low and may need medical attention.',
    whatItMeans: [
      'SpO2 of 95–100%: Your blood is carrying enough oxygen.',
      'SpO2 of 90–94%: Mildly low — monitor closely and contact your doctor.',
      'SpO2 below 90%: Low — seek medical attention, especially if you have breathing difficulty.',
    ],
    whenToSeekHelp: 'Seek immediate care if SpO2 drops below 90% or you feel short of breath, confused, or have blue lips.',
    tips: 'Fingernail polish, cold fingers, or poor circulation can give inaccurate readings. Use a well-lit room.',
  },
};

const CHART_BANDS: Record<string, { low: number; high: number; label: string }> = {
  bp: { low: 90, high: 120, label: '90–120 mmHg' },
  hr: { low: 60, high: 100, label: '60–100 bpm' },
  weight: { low: 45, high: 90, label: '45–90 kg' },
  sugar: { low: 70, high: 100, label: '70–100 mg/dL' },
  temp: { low: 36, high: 37.2, label: '36–37.2 °C' },
  spo2: { low: 95, high: 100, label: '95–100%' },
};

type Reading = {
  label: string;
  value: string;
  unit: string;
  band: VitalBand;
  detail?: string;
};

function celsiusToFahrenheit(c: number): number {
  return c * 9 / 5 + 32;
}

function getReadings(v: VitalSign): Reading[] {
  const readings: Reading[] = [];
  if (v.blood_pressure_systolic && v.blood_pressure_diastolic)
    readings.push({
      label: 'BP',
      value: `${v.blood_pressure_systolic}/${v.blood_pressure_diastolic}`,
      unit: 'mmHg',
      band: analyzeBP(v.blood_pressure_systolic, v.blood_pressure_diastolic),
      detail: `Systolic ${v.blood_pressure_systolic} (top) / Diastolic ${v.blood_pressure_diastolic} (bottom)`,
    });
  if (v.heart_rate)
    readings.push({
      label: 'HR',
      value: String(v.heart_rate),
      unit: 'bpm',
      band: analyzeHR(v.heart_rate),
      detail: v.heart_rate < 60 ? 'Bradycardia (slow)' : v.heart_rate <= 100 ? 'Normal resting rate' : v.heart_rate <= 120 ? 'Elevated (check if resting)' : 'Tachycardia (fast)',
    });
  if (v.weight)
    readings.push({
      label: 'Weight',
      value: v.weight.toFixed(1),
      unit: 'kg',
      band: { level: 'ok', label: 'Recorded', band: { low: 45, high: 90 }, scale: { min: 30, max: 150 } },
    });
  if (v.blood_sugar)
    readings.push({
      label: 'Sugar',
      value: String(Math.round(v.blood_sugar)),
      unit: 'mg/dL',
      band: analyzeSugar(v.blood_sugar),
      detail: v.blood_sugar < 70 ? 'Hypoglycemia — eat something now' : v.blood_sugar <= 100 ? 'Normal fasting level' : v.blood_sugar <= 125 ? 'Prediabetic range — monitor closely' : 'High — consult your doctor',
    });
  if (v.temperature) {
    const f = celsiusToFahrenheit(v.temperature);
    readings.push({
      label: 'Temp',
      value: `${v.temperature.toFixed(1)}°C`,
      unit: `(${f.toFixed(1)}°F)`,
      band: analyzeTemp(v.temperature),
      detail: v.temperature < 35 ? 'Dangerously low body temperature' : v.temperature < 36 ? 'Below normal' : v.temperature <= 37.2 ? 'Normal body temperature' : v.temperature <= 38 ? 'Low-grade fever' : v.temperature <= 39 ? 'Fever — rest and hydrate' : 'High fever — seek medical care',
    });
  }
  if (v.oxygen_saturation)
    readings.push({
      label: 'SpO2',
      value: String(v.oxygen_saturation),
      unit: '%',
      band: analyzeSpO2(v.oxygen_saturation),
      detail: v.oxygen_saturation >= 95 ? 'Blood is well-oxygenated' : v.oxygen_saturation >= 90 ? 'Mildly low — monitor closely' : 'Low — seek medical attention',
    });
  return readings;
}

export default function Vitals() {
  const router = useRouter();
  const [vitals, setVitals] = useState<VitalSign[] | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [expandedInfo, setExpandedInfo] = useState<string | null>(null);
  const [formData, setFormData] = useState({
    blood_pressure_systolic: '', blood_pressure_diastolic: '', heart_rate: '',
    weight: '', blood_sugar: '', temperature: '', oxygen_saturation: '', notes: ''
  });
  const [chartType, setChartType] = useState('bp');
  const { listening, supported, toggle } = useSpeechRecognition(
    (text) => setFormData((prev) => ({ ...prev, notes: (prev.notes ? prev.notes + ' ' : '') + text }))
  );

  const fetchVitals = async (): Promise<VitalSign[]> => {
    const token = localStorage.getItem('token');
    const res = await apiFetch(`${API_URL}/api/vitals?limit=100`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    if (res.ok) {
      const data = await res.json();
      return data.vitals || [];
    }
    return [];
  };

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) { router.push('/auth/login'); return; }
    let cancelled = false;
    (async () => {
      try {
        const list = await fetchVitals();
        if (!cancelled) setVitals(list);
      } catch (err) { console.error(err); }
    })();
    return () => { cancelled = true; };
  }, [router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('token');
      const body: Record<string, number | string> = {};
      if (formData.blood_pressure_systolic) body.blood_pressure_systolic = parseInt(formData.blood_pressure_systolic);
      if (formData.blood_pressure_diastolic) body.blood_pressure_diastolic = parseInt(formData.blood_pressure_diastolic);
      if (formData.heart_rate) body.heart_rate = parseInt(formData.heart_rate);
      if (formData.weight) body.weight = parseFloat(formData.weight);
      if (formData.blood_sugar) body.blood_sugar = parseFloat(formData.blood_sugar);
      if (formData.temperature) body.temperature = parseFloat(formData.temperature);
      if (formData.oxygen_saturation) body.oxygen_saturation = parseInt(formData.oxygen_saturation);
      if (formData.notes) body.notes = formData.notes;

      const res = await apiFetch(`${API_URL}/api/vitals`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      });
      if (res.ok) {
        const list = await fetchVitals();
        setVitals(list);
        setShowForm(false);
        setFormData({ blood_pressure_systolic: '', blood_pressure_diastolic: '', heart_rate: '', weight: '', blood_sugar: '', temperature: '', oxygen_saturation: '', notes: '' });
      } else {
        const err = await res.json();
        alert(err.detail || 'Failed to add');
      }
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Failed to add');
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this vital sign entry?')) return;
    try {
      const token = localStorage.getItem('token');
      await apiFetch(`${API_URL}/api/vitals/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      setVitals((prev) => (prev ? prev.filter(v => v.id !== id) : prev));
    } catch (err) { console.error(err); }
  };

  const chartData = [...(vitals ?? [])].reverse().map((v, i) => ({
    name: `#${i + 1}`,
    date: formatServerDate(v.measured_at),
    systolic: v.blood_pressure_systolic,
    diastolic: v.blood_pressure_diastolic,
    heartRate: v.heart_rate,
    weight: v.weight,
    bloodSugar: v.blood_sugar,
    temperature: v.temperature,
    oxygenSaturation: v.oxygen_saturation,
  }));

  const loading = vitals === null;
  const band = CHART_BANDS[chartType];
  const info = VITAL_INFO[chartType];

  if (loading) {
    return (
      <div className="min-h-screen bg-surface">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Skeleton className="h-8 w-48 mb-8" />
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2 mb-6">
            {[1, 2, 3, 4, 5, 6].map((i) => <Skeleton key={i} className="h-12" />)}
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {[1, 2, 3].map((i) => <Skeleton key={i} className="h-40" />)}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-8">
          <h1 className="text-2xl sm:text-3xl font-display font-bold text-on-surface">Vital Signs</h1>
          <Button onClick={() => setShowForm(!showForm)} className="w-full sm:w-auto">
            {showForm ? 'Cancel' : (
              <>
                <Plus className="w-4 h-4" /> Add Reading
              </>
            )}
          </Button>
        </div>

        {/* Reference bands at a glance */}
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2 mb-6">
          {[
            { label: 'BP', desc: 'Normal <120/80', level: 'ok' as const },
            { label: 'HR', desc: 'Normal 60–100 bpm', level: 'ok' as const },
            { label: 'Sugar', desc: 'Fasting 70–100', level: 'ok' as const },
            { label: 'Temp', desc: '36.1–37.2°C / 97–99°F', level: 'ok' as const },
            { label: 'SpO2', desc: 'Normal ≥95%', level: 'ok' as const },
            { label: 'Weight', desc: 'Track trends', level: 'caution' as const },
          ].map((chip) => (
            <div key={chip.label} className={`text-center p-2 rounded-sm border ${
              chip.level === 'ok'
                ? 'bg-ok-container border-ok/40'
                : 'bg-caution-container border-caution/40'
            }`}>
              <span className={`text-xs font-semibold ${chip.level === 'ok' ? 'text-ok' : 'text-caution'}`}>{chip.label}</span>
              <span className={`block text-[10px] ${chip.level === 'ok' ? 'text-ok' : 'text-caution'}`}>{chip.desc}</span>
            </div>
          ))}
        </div>

        {showForm && (
          <Card className="p-lg mb-8">
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <div>
                  <Input label="Systolic BP (mmHg)" name="systolic" type="number" value={formData.blood_pressure_systolic}
                    onChange={e => setFormData({ ...formData, blood_pressure_systolic: e.target.value })} />
                  <p className="text-[11px] text-on-surface-variant mt-1">Top number — pressure when heart beats</p>
                </div>
                <div>
                  <Input label="Diastolic BP (mmHg)" name="diastolic" type="number" value={formData.blood_pressure_diastolic}
                    onChange={e => setFormData({ ...formData, blood_pressure_diastolic: e.target.value })} />
                  <p className="text-[11px] text-on-surface-variant mt-1">Bottom number — pressure when heart rests</p>
                </div>
                <div>
                  <Input label="Heart Rate (bpm)" name="hr" type="number" value={formData.heart_rate}
                    onChange={e => setFormData({ ...formData, heart_rate: e.target.value })} />
                  <p className="text-[11px] text-on-surface-variant mt-1">Beats per minute — count your pulse</p>
                </div>
                <Input label="Weight (kg)" name="weight" type="number" step="0.1" value={formData.weight}
                  onChange={e => setFormData({ ...formData, weight: e.target.value })} />
                <div>
                  <Input label="Blood Sugar (mg/dL)" name="sugar" type="number" step="1" value={formData.blood_sugar}
                    onChange={e => setFormData({ ...formData, blood_sugar: e.target.value })} />
                  <p className="text-[11px] text-on-surface-variant mt-1">Glucose level — measure fasting for best accuracy</p>
                </div>
                <div>
                  <Input label="Temperature (°C)" name="temp" type="number" step="0.1" value={formData.temperature}
                    onChange={e => setFormData({ ...formData, temperature: e.target.value })} />
                  <p className="text-[11px] text-on-surface-variant mt-1">
                    {formData.temperature ? `${celsiusToFahrenheit(parseFloat(formData.temperature)).toFixed(1)}°F` : 'Also shown in °F'}
                  </p>
                </div>
                <Input label="Oxygen Saturation (%)" name="spo2" type="number" value={formData.oxygen_saturation}
                  onChange={e => setFormData({ ...formData, oxygen_saturation: e.target.value })} />
              </div>
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label className="text-sm font-semibold text-on-surface">Notes</label>
                  {supported && (
                    <button
                      type="button"
                      onClick={toggle}
                      title={listening ? 'Stop voice input' : 'Dictate notes'}
                      className={`flex items-center gap-1.5 text-xs font-medium rounded-sm px-2 py-1.5 transition-colors ${
                        listening
                          ? 'bg-alert-container text-alert animate-pulse'
                          : 'bg-surface-card text-on-surface-variant border border-outline hover:text-on-surface'
                      }`}
                    >
                      <Mic className="w-3.5 h-3.5" />
                      {listening ? 'Listening…' : 'Speak'}
                    </button>
                  )}
                </div>
                <textarea
                  value={formData.notes}
                  onChange={e => setFormData({ ...formData, notes: e.target.value })}
                  placeholder="Feeling dizzy, after exercise, etc."
                  className="flex w-full min-h-[60px] rounded-sm border border-outline bg-surface-card px-3.5 py-2.5 text-base text-on-surface placeholder:text-on-surface-variant/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring"
                  rows={2}
                />
              </div>
              <div className="flex gap-2">
                <Button type="submit">Save Reading</Button>
                <Button type="button" variant="ghost" onClick={() => setShowForm(false)}>Cancel</Button>
              </div>
            </form>
          </Card>
        )}

        {vitals.length > 0 && (
          <Card className="p-lg mb-8">
            <div className="flex flex-col sm:flex-row items-start sm:items-center gap-3 mb-4">
              <h2 className="text-lg sm:text-xl font-display font-semibold text-on-surface">Trends</h2>
              <select value={chartType} onChange={e => { setChartType(e.target.value); setExpandedInfo(null); }}
                className="w-full sm:w-auto rounded-sm border border-outline bg-surface-card px-3 py-1.5 text-sm text-on-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring">
                <option value="bp">Blood Pressure</option>
                <option value="hr">Heart Rate</option>
                <option value="weight">Weight</option>
                <option value="sugar">Blood Sugar</option>
                <option value="temp">Temperature</option>
                <option value="spo2">Oxygen Saturation</option>
              </select>
              <span className="inline-flex items-center rounded-full bg-ok-container text-ok px-3 py-1 text-xs font-semibold">
                Normal: {band.label}
              </span>
            </div>

            {/* Detailed info panel for current chart type */}
            {info && (
              <div className="mb-6 border border-[var(--color-outline-subtle)] rounded-[var(--radius-md)] overflow-hidden">
                <button
                  onClick={() => setExpandedInfo(expandedInfo === chartType ? null : chartType)}
                  className="w-full flex items-center gap-3 px-4 py-3 bg-[var(--color-muted)] hover:bg-[var(--color-outline-subtle)] transition-colors text-left"
                >
                  <info.icon className="w-5 h-5 text-[var(--color-primary)] shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-on-surface">{info.fullName}</p>
                    <p className="text-xs text-on-surface-variant">Normal: {info.normalRange}</p>
                  </div>
                  <Info className="w-4 h-4 text-on-surface-variant shrink-0" />
                </button>
                {expandedInfo === chartType && (
                  <div className="px-4 py-4 space-y-3 bg-white dark:bg-[var(--color-card)]">
                    <div>
                      <p className="text-xs font-semibold text-on-surface mb-1">What does it measure?</p>
                      <p className="text-sm text-on-surface-variant">{info.whatItMeasures}</p>
                    </div>
                    <div>
                      <p className="text-xs font-semibold text-on-surface mb-1">What is normal?</p>
                      <p className="text-sm text-on-surface-variant">{info.whatIsNormal}</p>
                    </div>
                    <div>
                      <p className="text-xs font-semibold text-on-surface mb-1">Understanding your reading:</p>
                      <ul className="space-y-1.5">
                        {info.whatItMeans.map((item, i) => (
                          <li key={i} className="flex gap-2 text-sm text-on-surface-variant">
                            <span className="text-[var(--color-primary)] mt-0.5 shrink-0">&#8226;</span>
                            <span>{item}</span>
                          </li>
                        ))}
                      </ul>
                    </div>
                    <div className="bg-[var(--color-alert-container)] rounded-sm px-3 py-2">
                      <p className="text-xs font-semibold text-[var(--color-alert)] mb-0.5">When to seek help</p>
                      <p className="text-xs text-[var(--color-alert)]">{info.whenToSeekHelp}</p>
                    </div>
                    <div className="bg-[var(--color-ok-container)] rounded-sm px-3 py-2">
                      <p className="text-xs font-semibold text-[var(--color-ok)] mb-0.5">Measurement tips</p>
                      <p className="text-xs text-[var(--color-ok)]">{info.tips}</p>
                    </div>
                  </div>
                )}
              </div>
            )}

            <div className="w-full" style={{ height: 280, minHeight: 280 }}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={chartData}>
                  <XAxis dataKey="date" tick={{ fontSize: 11, fill: 'var(--color-on-surface-variant)' }} tickLine={false} axisLine={{ stroke: 'var(--color-outline)' }} />
                  <YAxis
                    tick={{ fontSize: 11, fill: 'var(--color-on-surface-variant)' }}
                    tickLine={false}
                    axisLine={false}
                    width={40}
                    domain={chartType === 'temp' ? [35, 42] : chartType === 'spo2' ? [80, 100] : ['auto', 'auto']}
                  />
                  <Tooltip
                    contentStyle={{ background: 'var(--color-surface-card)', border: '1px solid var(--color-outline)', borderRadius: 8, fontSize: 12 }}
                    labelStyle={{ color: 'var(--color-on-surface-variant)' }}
                    formatter={(value: React.ReactNode, name: React.ReactNode) => {
                      if (chartType === 'temp' && typeof value === 'number') {
                        return [`${value.toFixed(1)}°C (${celsiusToFahrenheit(value).toFixed(1)}°F)`, name];
                      }
                      return [value, name];
                    }}
                  />
                  <ReferenceArea y1={band.low} y2={band.high} fill="var(--color-primary)" fillOpacity={0.08} />
                  {chartType === 'bp' && (
                    <>
                      <Legend wrapperStyle={{ fontSize: 12, color: 'var(--color-on-surface-variant)' }} />
                      <Line type="monotone" dataKey="systolic" stroke="var(--color-series-1)" name="Systolic (top)" strokeWidth={2} dot={false} />
                      <Line type="monotone" dataKey="diastolic" stroke="var(--color-series-2)" name="Diastolic (bottom)" strokeWidth={2} dot={false} />
                    </>
                  )}
                  {chartType === 'hr' && <Line type="monotone" dataKey="heartRate" stroke="var(--color-series-1)" name="Heart Rate (bpm)" strokeWidth={2} dot={false} />}
                  {chartType === 'weight' && <Line type="monotone" dataKey="weight" stroke="var(--color-series-1)" name="Weight (kg)" strokeWidth={2} dot={false} />}
                  {chartType === 'sugar' && <Line type="monotone" dataKey="bloodSugar" stroke="var(--color-series-1)" name="Blood Sugar (mg/dL)" strokeWidth={2} dot={false} />}
                  {chartType === 'temp' && <Line type="monotone" dataKey="temperature" stroke="var(--color-series-1)" name="Temperature (°C / °F)" strokeWidth={2} dot={false} />}
                  {chartType === 'spo2' && <Line type="monotone" dataKey="oxygenSaturation" stroke="var(--color-series-1)" name="SpO2 (%)" strokeWidth={2} dot={false} />}
                </LineChart>
              </ResponsiveContainer>
            </div>
          </Card>
        )}

        {vitals.length === 0 ? (
          <Card className="p-lg">
            <EmptyState
              icon={Activity}
              title="No vital sign readings yet"
              description="Record your first reading and it will get a range bar, a band name and a trend to follow."
              action={<Button onClick={() => setShowForm(true)}>Add Your First Reading</Button>}
            />
          </Card>
        ) : (
          <div>
            <div className="flex items-center gap-2 mb-4">
              <h2 className="text-xl font-display font-semibold text-on-surface">History</h2>
              <span className="text-xs text-on-surface-variant">(each reading judged against its band)</span>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {vitals.map(v => {
                const readings = getReadings(v);
                return (
                  <Card key={v.id} className="p-lg">
                    <div className="flex justify-between items-start mb-3">
                      <p className="text-xs text-on-surface-variant tabular-nums">{formatServerDateTime(v.measured_at)}</p>
                      <button
                        onClick={() => handleDelete(v.id)}
                        className="text-alert/60 hover:text-alert transition-colors"
                        aria-label="Delete this reading"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </div>
                    <div className="divide-y divide-outline">
                      {readings.map((r, i) => (
                        <div key={i} className="py-2.5">
                          <div className="flex items-center justify-between gap-2">
                            <div className="min-w-0">
                              <span className="text-xs font-medium text-on-surface-variant">{r.label}</span>
                              <span className="block text-[11px] text-on-surface-variant/70 tabular-nums">
                                Normal: {r.band.band.low}–{r.band.band.high} {r.unit}
                              </span>
                            </div>
                            <div className="flex items-center gap-2 shrink-0">
                              <span className="font-display font-semibold text-on-surface tabular-nums">
                                {r.value} <span className="text-xs font-normal text-on-surface-variant">{r.unit}</span>
                              </span>
                              <StatusChip level={r.band.level} label={r.band.label} trend={r.band.trend} />
                            </div>
                          </div>
                          {r.detail && (
                            <p className="text-[11px] text-on-surface-variant mt-1 pl-0.5">{r.detail}</p>
                          )}
                        </div>
                      ))}
                    </div>
                    {v.notes && <p className="text-xs text-on-surface-variant mt-2 italic">{v.notes}</p>}
                  </Card>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
