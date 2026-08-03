'use client';

/**
 * The medicine list + add form, used both by a patient on /medicines and by a
 * caretaker on /care/[patientId].
 *
 * Pass `patientId` to operate on someone else's list; omit it for your own.
 * Every request goes through `scopedUrl`, which handles the '#' in user ids.
 */

import { useCallback, useEffect, useState } from 'react';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Input } from '@/components/input';
import { cacheGet, cacheSet } from '@/lib/offlineCache';
import { API_URL, CareAccessRevoked, authHeaders, scopedUrl } from '@/lib/care';

export interface Medicine {
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

const EMPTY_FORM = {
  name: '',
  dosage: '',
  frequency: '',
  start_date: '',
  end_date: '',
  notes: '',
};

export interface MedicineManagerProps {
  /** Whose medicines to manage. Omitted means the signed-in user's own. */
  patientId?: string;
  /** Called when the server reports the care link is gone. */
  onAccessRevoked?: () => void;
  /** Notifies the parent after any change, so summaries can refresh. */
  onChanged?: () => void;
}

export function MedicineManager({
  patientId,
  onAccessRevoked,
  onChanged,
}: MedicineManagerProps) {
  const [medicines, setMedicines] = useState<Medicine[]>([]);
  const [interactions, setInteractions] = useState<Interaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [offlineCopy, setOfflineCopy] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState(EMPTY_FORM);
  const [takingTimes, setTakingTimes] = useState<string[]>(['']);
  const [error, setError] = useState('');

  // Caching is for your own list only. Writing another person's medicines into
  // this device's offline store would leave their data behind after the link
  // ends, so a caretaker view never caches.
  const isSelf = !patientId;

  const handle = useCallback(
    (err: unknown) => {
      if (err instanceof CareAccessRevoked) {
        onAccessRevoked?.();
        return true;
      }
      return false;
    },
    [onAccessRevoked],
  );

  const fetchMedicines = useCallback(async () => {
    try {
      const res = await fetch(scopedUrl('/api/medicines', patientId), {
        headers: authHeaders(),
      });
      if (res.status === 403) throw new CareAccessRevoked();
      if (!res.ok) throw new Error('bad response');

      const data = await res.json();
      const list: Medicine[] = data.medicines || [];
      setMedicines(list);
      setOfflineCopy(false);
      if (isSelf) cacheSet('medicines', list);
    } catch (err) {
      if (handle(err)) return;
      if (!isSelf) {
        setError('Could not load medicines. Check your connection.');
        return;
      }
      const cached = await cacheGet<Medicine[]>('medicines');
      if (cached && cached.data.length) {
        setMedicines(cached.data);
        setOfflineCopy(true);
      }
    } finally {
      setLoading(false);
    }
  }, [patientId, isSelf, handle]);

  const fetchInteractions = useCallback(async () => {
    try {
      const res = await fetch(scopedUrl('/api/medicines/interactions', patientId), {
        headers: authHeaders(),
      });
      if (res.ok) {
        const data = await res.json();
        setInteractions(data.interactions || []);
      }
    } catch {
      /* interactions are advisory; a failure here shouldn't block the list */
    }
  }, [patientId]);

  useEffect(() => {
    setLoading(true);
    fetchMedicines();
    fetchInteractions();
  }, [fetchMedicines, fetchInteractions]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    const validTimes = takingTimes.filter((t) => t.trim());
    try {
      const res = await fetch(scopedUrl('/api/medicines', patientId), {
        method: 'POST',
        headers: { ...authHeaders(), 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...formData,
          end_date: formData.end_date || null,
          notes: formData.notes || null,
          taking_times: validTimes.length > 0 ? JSON.stringify(validTimes) : null,
        }),
      });
      if (res.status === 403) throw new CareAccessRevoked();
      if (!res.ok) {
        const err = await res.json().catch(() => null);
        setError(err?.detail || 'Failed to add medicine');
        return;
      }
      const created = await res.json();
      setMedicines([created, ...medicines]);
      setShowForm(false);
      setFormData(EMPTY_FORM);
      setTakingTimes(['']);
      fetchInteractions();
      onChanged?.();
    } catch (err) {
      if (handle(err)) return;
      setError('Failed to add medicine');
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Remove this medicine?')) return;
    try {
      const res = await fetch(scopedUrl(`/api/medicines/${id}`, patientId), {
        method: 'DELETE',
        headers: authHeaders(),
      });
      if (res.status === 403) throw new CareAccessRevoked();
      if (res.ok) {
        setMedicines(medicines.filter((m) => m.id !== id));
        fetchInteractions();
        onChanged?.();
      }
    } catch (err) {
      handle(err);
    }
  };

  const updateTime = (i: number, val: string) => {
    const updated = [...takingTimes];
    updated[i] = val;
    setTakingTimes(updated);
  };

  const parseTimes = (tt?: string): string[] => {
    if (!tt) return [];
    try {
      return JSON.parse(tt);
    } catch {
      return [];
    }
  };

  if (loading) {
    return <p className="text-subtext py-8">Loading…</p>;
  }

  return (
    <>
      {offlineCopy && (
        <div className="mb-6 rounded-lg bg-amber-50 border border-amber-200 px-4 py-2.5">
          <p className="text-sm text-amber-800">
            Showing an offline copy — reconnect to load the latest.
          </p>
        </div>
      )}

      {error && (
        <div className="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-2.5 text-sm text-red-800">
          {error}
        </div>
      )}

      {interactions.length > 0 && (
        <div className="mb-6 rounded-xl border border-red-200 bg-red-50 p-4">
          <h2 className="font-semibold text-red-800 mb-3">
            Possible Drug Interactions ({interactions.length})
          </h2>
          <div className="space-y-2">
            {interactions.map((it, i) => (
              <div
                key={i}
                className={`rounded-lg border px-3 py-2 ${SEVERITY_STYLES[it.severity]}`}
              >
                <div className="flex items-center gap-2 mb-0.5">
                  <span className="text-[10px] font-bold uppercase tracking-wide">
                    {it.severity}
                  </span>
                  <span className="text-sm font-medium">
                    {it.drug_a} + {it.drug_b}
                  </span>
                </div>
                <p className="text-xs">{it.description}</p>
              </div>
            ))}
          </div>
          <p className="text-[11px] text-red-700 mt-3">
            Educational check only — always confirm with your doctor or pharmacist.
          </p>
        </div>
      )}

      <div className="mb-6">
        <Button onClick={() => setShowForm(!showForm)}>
          {showForm ? 'Cancel' : '+ Add Medicine'}
        </Button>
      </div>

      {showForm && (
        <Card className="p-6 mb-8">
          <form onSubmit={handleSubmit} className="space-y-4">
            <Input
              label="Medicine Name"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              placeholder="e.g., Aspirin"
              required
            />
            <Input
              label="Dosage"
              value={formData.dosage}
              onChange={(e) => setFormData({ ...formData, dosage: e.target.value })}
              placeholder="e.g., 500mg"
              required
            />
            <Input
              label="Frequency"
              value={formData.frequency}
              onChange={(e) => setFormData({ ...formData, frequency: e.target.value })}
              placeholder="e.g., Once daily"
              required
            />
            <Input
              label="Start Date"
              type="date"
              value={formData.start_date}
              onChange={(e) => setFormData({ ...formData, start_date: e.target.value })}
              required
            />
            <Input
              label="End Date (optional)"
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
                    <button
                      type="button"
                      onClick={() => setTakingTimes(takingTimes.filter((_, x) => x !== i))}
                      className="text-red-500 text-sm hover:underline"
                    >
                      Remove
                    </button>
                  )}
                </div>
              ))}
              <button
                type="button"
                onClick={() => setTakingTimes([...takingTimes, ''])}
                className="text-primary text-sm hover:underline self-start"
              >
                + Add another time
              </button>
            </div>

            <Input
              label="Notes"
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
          <Button onClick={() => setShowForm(true)}>Add the first medicine</Button>
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
                    <p className="text-subtext text-xs font-medium uppercase tracking-wider mb-1">
                      Taking Times
                    </p>
                    <div className="flex flex-wrap gap-1.5">
                      {times.map((t, i) => (
                        <span
                          key={i}
                          className="inline-flex items-center px-2 py-0.5 rounded-md bg-blue-50 text-blue-700 text-xs font-medium"
                        >
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
                {med.notes && <p className="text-subtext text-sm mb-4">{med.notes}</p>}
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
    </>
  );
}
