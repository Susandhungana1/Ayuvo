'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Input } from '@/components/input';
import { cacheGet, cacheSet } from '@/lib/offlineCache';
import { ensurePushSubscription } from '@/components/medicine-alarm';

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

interface Interaction {
  drug_a: string;
  drug_b: string;
  severity: 'severe' | 'moderate' | 'minor';
  description: string;
}

const SEVERITY_STYLES: Record<string, string> = {
  severe: 'bg-red-100 text-red-800 border-red-300',
  moderate: 'bg-amber-100 text-amber-800 border-amber-300',
  minor: 'bg-yellow-50 text-yellow-800 border-yellow-200',
};

export default function Medicines() {
  const router = useRouter();
  const [medicines, setMedicines] = useState<Medicine[]>([]);
  const [loading, setLoading] = useState(true);
  const [offlineCopy, setOfflineCopy] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    dosage: '',
    frequency: '',
    start_date: '',
    end_date: '',
    notes: ''
  });
  const [takingTimes, setTakingTimes] = useState<string[]>(['']);
  const [interactions, setInteractions] = useState<Interaction[]>([]);
  const [reminderStatus, setReminderStatus] = useState('');
  const [enablingReminders, setEnablingReminders] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    fetchMedicines();
    fetchInteractions();
    requestNotificationPermission();
  }, [router]);

  const fetchInteractions = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/medicines/interactions`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setInteractions(data.interactions || []);
      }
    } catch (err) { console.error(err); }
  };

  const requestNotificationPermission = async () => {
    if (!('Notification' in window)) return;
    if (Notification.permission === 'default') {
      await Notification.requestPermission();
    }
  };

  // Explicit user tap: request permission (iOS requires a gesture), register
  // this device, then send a test push so the user can confirm delivery.
  const enableAndTestReminders = async () => {
    setEnablingReminders(true);
    setReminderStatus('');
    try {
      if (!('Notification' in window)) {
        setReminderStatus('This device does not support notifications.');
        return;
      }
      let perm = Notification.permission;
      if (perm === 'default') perm = await Notification.requestPermission();
      if (perm !== 'granted') {
        setReminderStatus('Notifications are off. On iPhone, install the app to your Home Screen, then allow notifications.');
        return;
      }
      const subscribed = await ensurePushSubscription();
      if (!subscribed) {
        setReminderStatus('Could not register this device. Make sure the app is opened from your Home Screen icon.');
        return;
      }
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/push/test`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
      });
      if (!res.ok) {
        setReminderStatus('Reminders are enabled, but the test could not be sent. Try again in a moment.');
        return;
      }
      const data = await res.json();
      if (data.sent > 0) {
        setReminderStatus(`✅ Reminders enabled. Test sent to ${data.sent} device(s) — check your lock screen.`);
      } else {
        setReminderStatus('Enabled, but no device received the test. Close and reopen the app from the Home Screen, then try again.');
      }
    } catch {
      setReminderStatus('Something went wrong enabling reminders. Please try again.');
    } finally {
      setEnablingReminders(false);
    }
  };

  const fetchMedicines = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/medicines`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        const list = data.medicines || [];
        setMedicines(list);
        setOfflineCopy(false);
        cacheSet('medicines', list); // keep a local copy for offline viewing
        return;
      }
      throw new Error('bad response');
    } catch (err) {
      const cached = await cacheGet<Medicine[]>('medicines');
      if (cached && cached.data.length) {
        setMedicines(cached.data);
        setOfflineCopy(true);
      } else {
        console.error(err);
      }
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const validTimes = takingTimes.filter(t => t.trim());
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/medicines`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          name: formData.name,
          dosage: formData.dosage,
          frequency: formData.frequency,
          start_date: formData.start_date,
          end_date: formData.end_date || null,
          taking_times: validTimes.length > 0 ? JSON.stringify(validTimes) : null,
          notes: formData.notes || null
        })
      });
      if (res.ok) {
        const newMedicine = await res.json();
        setMedicines([newMedicine, ...medicines]);
        setShowForm(false);
        setFormData({ name: '', dosage: '', frequency: '', start_date: '', end_date: '', notes: '' });
        setTakingTimes(['']);
        fetchInteractions();
      } else {
        const err = await res.json();
        alert(err.detail || 'Failed to add medicine');
      }
    } catch (err: any) {
      alert(err.message || 'Failed to add medicine');
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Remove this medicine?')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/medicines/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        setMedicines(medicines.filter(m => m.id !== id));
        fetchInteractions();
      }
    } catch (err) {
      console.error(err);
    }
  };

  const addTimeField = () => setTakingTimes([...takingTimes, '']);

  const removeTimeField = (i: number) => {
    if (takingTimes.length <= 1) return;
    setTakingTimes(takingTimes.filter((_, idx) => idx !== i));
  };

  const updateTime = (i: number, val: string) => {
    const updated = [...takingTimes];
    updated[i] = val;
    setTakingTimes(updated);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-subtext">Loading...</p>
      </div>
    );
  }

  const parseTimes = (tt?: string): string[] => {
    if (!tt) return [];
    try { return JSON.parse(tt); } catch { return []; }
  };

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-text-main">Medicines</h1>
        </div>

        {offlineCopy && (
          <div className="mb-6 flex items-center gap-2 rounded-lg bg-amber-50 border border-amber-200 px-4 py-2.5">
            <svg className="w-4 h-4 text-amber-600 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18.364 5.636a9 9 0 010 12.728m0 0l-2.829-2.829m2.829 2.829L21 21M15.536 8.464a5 5 0 010 7.072m0 0l-2.829-2.829m-4.243 2.829a4.978 4.978 0 01-1.414-2.83m-1.414 5.658a9 9 0 01-2.167-9.238m7.824 2.167a1 1 0 111.414 1.414m-1.414-1.414L3 3m8.293 8.293l1.414 1.414" />
            </svg>
            <p className="text-sm text-amber-800">Showing an offline copy — reconnect to load the latest.</p>
          </div>
        )}

        {interactions.length > 0 && (
          <div className="mb-6 rounded-xl border border-red-200 bg-red-50 p-4">
            <div className="flex items-center gap-2 mb-3">
              <svg className="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4.5c-.77-.833-1.964-.833-2.732 0L4.068 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
              <h2 className="font-semibold text-red-800">Possible Drug Interactions ({interactions.length})</h2>
            </div>
            <div className="space-y-2">
              {interactions.map((it, i) => (
                <div key={i} className={`rounded-lg border px-3 py-2 ${SEVERITY_STYLES[it.severity]}`}>
                  <div className="flex items-center gap-2 mb-0.5">
                    <span className="text-[10px] font-bold uppercase tracking-wide">{it.severity}</span>
                    <span className="text-sm font-medium">{it.drug_a} + {it.drug_b}</span>
                  </div>
                  <p className="text-xs">{it.description}</p>
                </div>
              ))}
            </div>
            <p className="text-[11px] text-red-700 mt-3">Educational check only — always confirm with your doctor or pharmacist.</p>
          </div>
        )}

        <div className="mb-6 flex flex-wrap items-center gap-3">
          <Button onClick={() => setShowForm(!showForm)}>
            {showForm ? 'Cancel' : '+ Add Medicine'}
          </Button>
          <button
            type="button"
            onClick={enableAndTestReminders}
            disabled={enablingReminders}
            className="inline-flex items-center gap-1.5 rounded-md border border-primary/40 bg-primary/5 px-3 py-2 text-sm font-medium text-primary hover:bg-primary/10 disabled:opacity-60"
          >
            🔔 {enablingReminders ? 'Enabling…' : 'Enable & test reminders'}
          </button>
        </div>

        {reminderStatus && (
          <div className="mb-6 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2.5 text-sm text-blue-800">
            {reminderStatus}
          </div>
        )}

        {showForm && (
          <Card className="p-6 mb-8">
            <form onSubmit={handleSubmit} className="space-y-4">
              <Input
                label="Medicine Name"
                name="name"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="e.g., Aspirin"
                required
              />
              <Input
                label="Dosage"
                name="dosage"
                value={formData.dosage}
                onChange={(e) => setFormData({ ...formData, dosage: e.target.value })}
                placeholder="e.g., 500mg"
                required
              />
              <Input
                label="Frequency"
                name="frequency"
                value={formData.frequency}
                onChange={(e) => setFormData({ ...formData, frequency: e.target.value })}
                placeholder="e.g., Once daily"
                required
              />
              <Input
                label="Start Date"
                name="start_date"
                type="date"
                value={formData.start_date}
                onChange={(e) => setFormData({ ...formData, start_date: e.target.value })}
                required
              />
              <Input
                label="End Date (optional)"
                name="end_date"
                type="date"
                value={formData.end_date}
                onChange={(e) => setFormData({ ...formData, end_date: e.target.value })}
              />

              <div className="flex flex-col gap-1.5 w-full">
                <label className="text-sm font-medium text-gray-700">Taking Times</label>
                {takingTimes.map((t, i) => (
                  <div key={i} className="flex items-center gap-2">
                    <input
                      type="time"
                      value={t}
                      onChange={(e) => updateTime(i, e.target.value)}
                      className="flex h-10 rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
                    />
                    {takingTimes.length > 1 && (
                      <button type="button" onClick={() => removeTimeField(i)} className="text-red-500 text-sm hover:underline">Remove</button>
                    )}
                  </div>
                ))}
                <button type="button" onClick={addTimeField} className="text-primary text-sm hover:underline self-start">+ Add another time</button>
              </div>

              <Input
                label="Notes"
                name="notes"
                value={formData.notes}
                onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                placeholder="Additional notes..."
              />
              <Button type="submit">Add Medicine</Button>
            </form>
          </Card>
        )}

        {medicines.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext mb-4">No medicines tracked yet</p>
            <Button onClick={() => setShowForm(true)}>Add Your First Medicine</Button>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {medicines.map((med) => {
              const times = parseTimes(med.taking_times);
              return (
                <Card key={med.id} className="p-6">
                  <h3 className="text-lg font-semibold text-text-main mb-2">{med.name}</h3>
                  <p className="text-subtext text-sm mb-1">Dosage: {med.dosage}</p>
                  <p className="text-subtext text-sm mb-1">Frequency: {med.frequency}</p>
                  {times.length > 0 && (
                    <div className="mb-2">
                      <p className="text-subtext text-xs font-medium uppercase tracking-wider mb-1">Taking Times</p>
                      <div className="flex flex-wrap gap-1.5">
                        {times.map((t, i) => (
                          <span key={i} className="inline-flex items-center px-2 py-0.5 rounded-md bg-blue-50 text-blue-700 text-xs font-medium">
                            {t}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}
                  <p className="text-subtext text-sm mb-1">
                    Started: {new Date(med.start_date).toLocaleDateString()}
                  </p>
                  {med.end_date && (
                    <p className="text-subtext text-sm mb-1">
                      Ends: {new Date(med.end_date).toLocaleDateString()}
                    </p>
                  )}
                  {med.notes && (
                    <p className="text-subtext text-sm mb-4">{med.notes}</p>
                  )}
                  <button
                    onClick={() => handleDelete(med.id)}
                    className="text-red-500 text-sm hover:underline"
                  >
                    Remove
                  </button>
                </Card>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
