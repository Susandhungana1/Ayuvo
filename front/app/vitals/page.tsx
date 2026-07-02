'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Input } from '@/components/input';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer
} from 'recharts';

const API_URL = 'http://127.0.0.1:3001';

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

type VitalReading = {
  label: string;
  value: string;
  unit: string;
  color: string;
  bg: string;
  status: string;
  range: string;
};

function analyzeBP(systolic: number, diastolic: number): VitalReading {
  const label = 'BP';
  const value = `${systolic}/${diastolic}`;
  const unit = 'mmHg';
  let color: string, bg: string, status: string;
  if (systolic < 90 || diastolic < 60) {
    color = 'text-rose-800'; bg = 'bg-rose-100'; status = 'Low';
  } else if (systolic < 120 && diastolic < 80) {
    color = 'text-green-800'; bg = 'bg-green-100'; status = 'Normal';
  } else if (systolic < 130 && diastolic < 80) {
    color = 'text-yellow-800'; bg = 'bg-yellow-100'; status = 'Elevated';
  } else if (systolic < 140 || diastolic < 90) {
    color = 'text-orange-800'; bg = 'bg-orange-100'; status = 'Stage 1 High';
  } else if (systolic < 180 || diastolic < 120) {
    color = 'text-red-800'; bg = 'bg-red-100'; status = 'Stage 2 High';
  } else {
    color = 'text-red-900'; bg = 'bg-red-200'; status = 'Crisis';
  }
  return { label, value, unit, color, bg, status, range: '<120/80' };
}

function analyzeHR(hr: number): VitalReading {
  const label = 'HR';
  const value = String(hr);
  const unit = 'bpm';
  let color: string, bg: string, status: string;
  if (hr < 60) {
    color = 'text-rose-800'; bg = 'bg-rose-100'; status = 'Low';
  } else if (hr <= 100) {
    color = 'text-green-800'; bg = 'bg-green-100'; status = 'Normal';
  } else if (hr <= 120) {
    color = 'text-orange-800'; bg = 'bg-orange-100'; status = 'Mild High';
  } else {
    color = 'text-red-800'; bg = 'bg-red-100'; status = 'High';
  }
  return { label, value, unit, color, bg, status, range: '60-100' };
}

function analyzeSugar(sugar: number): VitalReading {
  const label = 'BS';
  const value = String(Math.round(sugar));
  const unit = 'mg/dL';
  let color: string, bg: string, status: string;
  if (sugar < 70) {
    color = 'text-rose-800'; bg = 'bg-rose-100'; status = 'Low';
  } else if (sugar <= 100) {
    color = 'text-green-800'; bg = 'bg-green-100'; status = 'Normal';
  } else if (sugar <= 125) {
    color = 'text-orange-800'; bg = 'bg-orange-100'; status = 'Prediabetic';
  } else if (sugar <= 180) {
    color = 'text-red-800'; bg = 'bg-red-100'; status = 'High';
  } else {
    color = 'text-red-900'; bg = 'bg-red-200'; status = 'Very High';
  }
  return { label, value, unit, color, bg, status, range: '70-100' };
}

function analyzeTemp(temp: number): VitalReading {
  const label = 'Temp';
  const value = temp.toFixed(1);
  const unit = '°C';
  let color: string, bg: string, status: string;
  if (temp < 35.0) {
    color = 'text-red-800'; bg = 'bg-red-100'; status = 'Hypothermia';
  } else if (temp < 36.0) {
    color = 'text-rose-800'; bg = 'bg-rose-100'; status = 'Low';
  } else if (temp <= 37.2) {
    color = 'text-green-800'; bg = 'bg-green-100'; status = 'Normal';
  } else if (temp <= 38.0) {
    color = 'text-orange-800'; bg = 'bg-orange-100'; status = 'Mild Fever';
  } else if (temp <= 39.0) {
    color = 'text-red-800'; bg = 'bg-red-100'; status = 'Fever';
  } else {
    color = 'text-red-900'; bg = 'bg-red-200'; status = 'High Fever';
  }
  return { label, value, unit, color, bg, status, range: '36.1-37.2' };
}

function analyzeSpO2(spo2: number): VitalReading {
  const label = 'SpO2';
  const value = String(spo2);
  const unit = '%';
  let color: string, bg: string, status: string;
  if (spo2 >= 95) {
    color = 'text-green-800'; bg = 'bg-green-100'; status = 'Normal';
  } else if (spo2 >= 90) {
    color = 'text-orange-800'; bg = 'bg-orange-100'; status = 'Mild Low';
  } else if (spo2 >= 80) {
    color = 'text-red-800'; bg = 'bg-red-100'; status = 'Low';
  } else {
    color = 'text-red-900'; bg = 'bg-red-200'; status = 'Critical';
  }
  return { label, value, unit, color, bg, status, range: '95-100' };
}

function analyzeWeight(w: number): VitalReading {
  return { label: 'Weight', value: w.toFixed(1), unit: 'kg', color: 'text-blue-800', bg: 'bg-blue-100', status: 'Recorded', range: '-' };
}

function getReadings(v: VitalSign): VitalReading[] {
  const readings: VitalReading[] = [];
  if (v.blood_pressure_systolic && v.blood_pressure_diastolic)
    readings.push(analyzeBP(v.blood_pressure_systolic, v.blood_pressure_diastolic));
  if (v.heart_rate) readings.push(analyzeHR(v.heart_rate));
  if (v.weight) readings.push(analyzeWeight(v.weight));
  if (v.blood_sugar) readings.push(analyzeSugar(v.blood_sugar));
  if (v.temperature) readings.push(analyzeTemp(v.temperature));
  if (v.oxygen_saturation) readings.push(analyzeSpO2(v.oxygen_saturation));
  return readings;
}

export default function Vitals() {
  const router = useRouter();
  const [vitals, setVitals] = useState<VitalSign[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    blood_pressure_systolic: '', blood_pressure_diastolic: '', heart_rate: '',
    weight: '', blood_sugar: '', temperature: '', oxygen_saturation: '', notes: ''
  });
  const [chartType, setChartType] = useState('bp');

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) { router.push('/auth/login'); return; }
    fetchVitals();
  }, [router]);

  const fetchVitals = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/vitals?limit=100`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setVitals(data.vitals || []);
      }
    } catch (err) { console.error(err);
    } finally { setLoading(false); }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('token');
      const body: Record<string, any> = {};
      if (formData.blood_pressure_systolic) body.blood_pressure_systolic = parseInt(formData.blood_pressure_systolic);
      if (formData.blood_pressure_diastolic) body.blood_pressure_diastolic = parseInt(formData.blood_pressure_diastolic);
      if (formData.heart_rate) body.heart_rate = parseInt(formData.heart_rate);
      if (formData.weight) body.weight = parseFloat(formData.weight);
      if (formData.blood_sugar) body.blood_sugar = parseFloat(formData.blood_sugar);
      if (formData.temperature) body.temperature = parseFloat(formData.temperature);
      if (formData.oxygen_saturation) body.oxygen_saturation = parseInt(formData.oxygen_saturation);
      if (formData.notes) body.notes = formData.notes;

      const res = await fetch(`${API_URL}/api/vitals`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      });
      if (res.ok) {
        fetchVitals();
        setShowForm(false);
        setFormData({ blood_pressure_systolic: '', blood_pressure_diastolic: '', heart_rate: '', weight: '', blood_sugar: '', temperature: '', oxygen_saturation: '', notes: '' });
      } else {
        const err = await res.json();
        alert(err.detail || 'Failed to add');
      }
    } catch (err: any) { alert(err.message); }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this vital sign entry?')) return;
    try {
      const token = localStorage.getItem('token');
      await fetch(`${API_URL}/api/vitals/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      setVitals(vitals.filter(v => v.id !== id));
    } catch (err) { console.error(err); }
  };

  const chartData = [...vitals].reverse().map((v, i) => ({
    name: `#${i + 1}`,
    date: new Date(v.measured_at).toLocaleDateString(),
    systolic: v.blood_pressure_systolic,
    diastolic: v.blood_pressure_diastolic,
    heartRate: v.heart_rate,
    weight: v.weight,
    bloodSugar: v.blood_sugar,
    temperature: v.temperature,
    oxygenSaturation: v.oxygen_saturation,
  }));

  if (loading) {
    return <div className="min-h-screen bg-background flex items-center justify-center"><p className="text-subtext">Loading...</p></div>;
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-text-main">Vital Signs</h1>
          <Button onClick={() => setShowForm(!showForm)} className="w-full sm:w-auto">{showForm ? 'Cancel' : '+ Add Reading'}</Button>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2 mb-6">
          <div className="text-center p-2 rounded bg-green-50 border border-green-200"><span className="text-xs font-semibold text-green-800">BP</span><span className="block text-[10px] text-green-700">Normal &lt;120/80</span></div>
          <div className="text-center p-2 rounded bg-green-50 border border-green-200"><span className="text-xs font-semibold text-green-800">HR</span><span className="block text-[10px] text-green-700">Normal 60-100</span></div>
          <div className="text-center p-2 rounded bg-green-50 border border-green-200"><span className="text-xs font-semibold text-green-800">Sugar</span><span className="block text-[10px] text-green-700">Normal 3.9-5.6</span></div>
          <div className="text-center p-2 rounded bg-green-50 border border-green-200"><span className="text-xs font-semibold text-green-800">Temp</span><span className="block text-[10px] text-green-700">Normal 36.1-37.2</span></div>
          <div className="text-center p-2 rounded bg-green-50 border border-green-200"><span className="text-xs font-semibold text-green-800">SpO2</span><span className="block text-[10px] text-green-700">Normal ≥95%</span></div>
          <div className="text-center p-2 rounded bg-blue-50 border border-blue-200"><span className="text-xs font-semibold text-blue-800">Weight</span><span className="block text-[10px] text-blue-700">Track changes</span></div>
        </div>

        {showForm && (
          <Card className="p-6 mb-8">
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <Input label="Systolic BP (mmHg)" name="systolic" type="number" value={formData.blood_pressure_systolic}
                  onChange={e => setFormData({ ...formData, blood_pressure_systolic: e.target.value })} />
                <Input label="Diastolic BP (mmHg)" name="diastolic" type="number" value={formData.blood_pressure_diastolic}
                  onChange={e => setFormData({ ...formData, blood_pressure_diastolic: e.target.value })} />
                <Input label="Heart Rate (bpm)" name="hr" type="number" value={formData.heart_rate}
                  onChange={e => setFormData({ ...formData, heart_rate: e.target.value })} />
                <Input label="Weight (kg)" name="weight" type="number" step="0.1" value={formData.weight}
                  onChange={e => setFormData({ ...formData, weight: e.target.value })} />
                <Input label="Blood Sugar (mg/dL)" name="sugar" type="number" step="1" value={formData.blood_sugar}
                  onChange={e => setFormData({ ...formData, blood_sugar: e.target.value })} />
                <Input label="Temperature (°C)" name="temp" type="number" step="0.1" value={formData.temperature}
                  onChange={e => setFormData({ ...formData, temperature: e.target.value })} />
                <Input label="Oxygen Saturation (%)" name="spo2" type="number" value={formData.oxygen_saturation}
                  onChange={e => setFormData({ ...formData, oxygen_saturation: e.target.value })} />
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700 block mb-1">Notes</label>
                <textarea value={formData.notes} onChange={e => setFormData({ ...formData, notes: e.target.value })}
                  placeholder="Feeling dizzy, after exercise, etc."
                  className="flex w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm"
                  rows={2} />
              </div>
              <Button type="submit">Save Reading</Button>
            </form>
          </Card>
        )}

        {vitals.length > 0 && (
          <Card className="p-6 mb-8">
            <div className="flex flex-col sm:flex-row items-start sm:items-center gap-3 mb-4">
              <h2 className="text-lg sm:text-xl font-semibold text-text-main">Trends</h2>
              <select value={chartType} onChange={e => setChartType(e.target.value)}
                className="w-full sm:w-auto border rounded-md px-3 py-1.5 text-sm">
                <option value="bp">Blood Pressure</option>
                <option value="hr">Heart Rate</option>
                <option value="weight">Weight</option>
                <option value="sugar">Blood Sugar</option>
                <option value="temp">Temperature</option>
                <option value="spo2">Oxygen Saturation</option>
              </select>
              <span className="text-xs text-green-700 bg-green-50 px-2 py-1 rounded border border-green-200">
                {chartType === 'bp' && 'Normal: <120/80 mmHg'}
                {chartType === 'hr' && 'Normal: 60-100 bpm'}
                {chartType === 'weight' && 'Track your weight trend'}
                {chartType === 'sugar' && 'Normal: 70-100 mg/dL'}
                {chartType === 'temp' && 'Normal: 36.1-37.2°C'}
                {chartType === 'spo2' && 'Normal: ≥95%'}
              </span>
            </div>
            <div className="w-full" style={{ height: 250, minHeight: 250 }}>
              {chartType === 'bp' ? (
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey="systolic" stroke="#ef4444" name="Systolic" />
                    <Line type="monotone" dataKey="diastolic" stroke="#3b82f6" name="Diastolic" />
                  </LineChart>
                </ResponsiveContainer>
              ) : chartType === 'hr' ? (
                <ResponsiveContainer>
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey="heartRate" stroke="#8b5cf6" name="Heart Rate (bpm)" />
                  </LineChart>
                </ResponsiveContainer>
              ) : chartType === 'weight' ? (
                <ResponsiveContainer>
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey="weight" stroke="#10b981" name="Weight (kg)" />
                  </LineChart>
                </ResponsiveContainer>
              ) : chartType === 'sugar' ? (
                <ResponsiveContainer>
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey="bloodSugar" stroke="#f59e0b" name="Blood Sugar" />
                  </LineChart>
                </ResponsiveContainer>
              ) : chartType === 'temp' ? (
                <ResponsiveContainer>
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                    <YAxis domain={[35, 42]} />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey="temperature" stroke="#ec4899" name="Temperature (°C)" />
                  </LineChart>
                </ResponsiveContainer>
              ) : (
                <ResponsiveContainer>
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                    <YAxis domain={[80, 100]} />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey="oxygenSaturation" stroke="#06b6d4" name="SpO2 (%)" />
                  </LineChart>
                </ResponsiveContainer>
              )}
            </div>
          </Card>
        )}

        {vitals.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext mb-4">No vital sign readings yet</p>
            <Button onClick={() => setShowForm(true)}>Add Your First Reading</Button>
          </Card>
        ) : (
          <div>
            <div className="flex items-center gap-2 mb-4">
              <h2 className="text-xl font-semibold text-text-main">History</h2>
              <span className="text-xs text-subtext">(color-coded by normal range)</span>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {vitals.map(v => {
                const readings = getReadings(v);
                return (
                <Card key={v.id} className="p-4">
                  <div className="flex justify-between items-start mb-3">
                    <p className="text-xs text-subtext">{new Date(v.measured_at).toLocaleString()}</p>
                    <button onClick={() => handleDelete(v.id)} className="text-red-400 text-xs hover:text-red-600">&times;</button>
                  </div>
                  <div className="space-y-2">
                    {readings.map((r, i) => (
                      <div key={i} className={`flex items-center justify-between px-2.5 py-1.5 rounded-md ${r.bg}`}>
                        <div className="flex items-center gap-1.5 min-w-0">
                          <span className="text-xs font-medium text-gray-600">{r.label}</span>
                          <span className={`text-xs ${r.color}`}>{r.range}</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <span className={`font-semibold text-sm ${r.color}`}>{r.value}</span>
                          <span className="text-xs text-gray-500">{r.unit}</span>
                          <span className={`text-[10px] font-medium px-1.5 py-0.5 rounded ${r.bg} ${r.color}`}>{r.status}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                  {v.notes && <p className="text-xs text-subtext mt-2 italic">{v.notes}</p>}
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
