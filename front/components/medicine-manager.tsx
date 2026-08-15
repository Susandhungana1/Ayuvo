'use client';

/**
 * The medicine list + add form, used both by a patient on /medicines and by a
 * caretaker on /care/[patientId].
 *
 * Pass `patientId` to operate on someone else's list; omit it for your own.
 * Every request goes through `scopedUrl`, which handles the '#' in user ids.
 */

import { useCallback, useEffect, useState } from 'react';
import { Pill, Plus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/ui/empty-state';
import { cacheGet, cacheSet } from '@/lib/offlineCache';
import { CareAccessRevoked, authHeaders, scopedUrl } from '@/lib/care';
import { formatPlainDate } from '@/lib/datetime';

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
  severe: 'bg-alert-container text-alert border-alert/40',
  moderate: 'bg-caution-container text-caution border-caution/40',
  minor: 'bg-surface-card text-caution border-outline',
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
  const [medicines, setMedicines] = useState<Medicine[] | null>(null);
  const [interactions, setInteractions] = useState<Interaction[]>([]);
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

  const fetchMedicines = useCallback(async (): Promise<Medicine[] | null> => {
    try {
      const res = await fetch(scopedUrl('/api/medicines', patientId), {
        headers: authHeaders(),
      });
      if (res.status === 403) throw new CareAccessRevoked();
      if (!res.ok) throw new Error('bad response');

      const data = await res.json();
      const list: Medicine[] = data.medicines || [];
      if (isSelf) cacheSet('medicines', list);
      return list;
    } catch (err) {
      if (handle(err)) return null;
      if (!isSelf) {
        setError('Could not load medicines. Check your connection.');
        return null;
      }
      const cached = await cacheGet<Medicine[]>('medicines');
      if (cached && cached.data.length) {
        setOfflineCopy(true);
        return cached.data;
      }
      return null;
    }
  }, [patientId, isSelf, handle]);

  const fetchInteractions = useCallback(async (): Promise<Interaction[]> => {
    try {
      const res = await fetch(scopedUrl('/api/medicines/interactions', patientId), {
        headers: authHeaders(),
      });
      if (res.ok) {
        const data = await res.json();
        return data.interactions || [];
      }
    } catch {
      /* interactions are advisory; a failure here shouldn't block the list */
    }
    return [];
  }, [patientId]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const list = await fetchMedicines();
      if (cancelled) return;
      if (list !== null) setMedicines(list);
      if (list === null) setMedicines([]);
      const its = await fetchInteractions();
      if (!cancelled) setInteractions(its);
    })();
    return () => { cancelled = true; };
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
      setMedicines((prev) => [created, ...(prev ?? [])]);
      setOfflineCopy(false);
      setShowForm(false);
      setFormData(EMPTY_FORM);
      setTakingTimes(['']);
      setInteractions(await fetchInteractions());
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
        setMedicines((prev) => (prev ? prev.filter((m) => m.id !== id) : prev));
        setInteractions(await fetchInteractions());
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

  const today = new Date().toISOString().slice(0, 10);

  if (medicines === null) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {[1, 2, 3].map((i) => <Skeleton key={i} className="h-44" />)}
      </div>
    );
  }

  const activeMeds = medicines.filter((m) => !m.end_date || m.end_date >= today);
  const endedMeds = medicines.filter((m) => m.end_date && m.end_date < today);

  const renderMedicineCard = (med: Medicine, isEnded: boolean) => {
    const times = parseTimes(med.taking_times);
    return (
      <Card key={med.id} className={`p-lg ${isEnded ? 'opacity-60' : ''}`}>
        <div className="flex items-start gap-sm mb-2">
          <div className={`w-9 h-9 rounded-sm flex items-center justify-center shrink-0 ${isEnded ? 'bg-on-surface-variant/10' : 'bg-primary/10'}`}>
            <Pill className={`w-4 h-4 ${isEnded ? 'text-on-surface-variant' : 'text-primary'}`} />
          </div>
          <div className="min-w-0">
            <h3 className="text-lg font-display font-semibold text-on-surface">{med.name}</h3>
            {isEnded && (
              <span className="inline-flex items-center px-2 py-0.5 rounded-sm bg-on-surface-variant/10 text-on-surface-variant text-xs font-medium">
                Ended
              </span>
            )}
          </div>
        </div>
        <p className="text-on-surface-variant text-sm mb-1">Dosage: {med.dosage}</p>
        <p className="text-on-surface-variant text-sm mb-1">Frequency: {med.frequency}</p>
        {times.length > 0 && (
          <div className="mb-2">
            <p className="text-on-surface-variant text-xs font-medium uppercase tracking-wider mb-1">
              Taking Times
            </p>
            <div className="flex flex-wrap gap-1.5">
              {times.map((t, i) => (
                <span
                  key={i}
                  className={`inline-flex items-center px-2 py-0.5 rounded-sm text-xs font-medium tabular-nums ${isEnded ? 'bg-on-surface-variant/10 text-on-surface-variant' : 'bg-primary/10 text-primary'}`}
                >
                  {t}
                </span>
              ))}
            </div>
          </div>
        )}
        <p className="text-on-surface-variant text-sm mb-1">
          Started: {formatPlainDate(med.start_date)}
        </p>
        {med.end_date && (
          <p className="text-on-surface-variant text-sm mb-1">
            Ended: {formatPlainDate(med.end_date)}
          </p>
        )}
        {med.notes && <p className="text-on-surface-variant text-sm mb-4">{med.notes}</p>}
        <button
          onClick={() => handleDelete(med.id)}
          className="text-alert text-sm hover:underline"
        >
          Remove
        </button>
      </Card>
    );
  };

  return (
    <>
      {offlineCopy && (
        <div className="mb-6 rounded-md bg-caution-container border border-caution/40 px-4 py-2.5">
          <p className="text-sm text-caution">
            Showing an offline copy — reconnect to load the latest.
          </p>
        </div>
      )}

      {error && (
        <div className="mb-6 rounded-md border border-alert/40 bg-alert-container px-4 py-2.5 text-sm text-alert">
          {error}
        </div>
      )}

      {interactions.length > 0 && (
        <div className="mb-6 rounded-lg border border-alert/40 bg-alert-container p-lg">
          <h2 className="font-display font-semibold text-alert mb-3">
            Possible Drug Interactions ({interactions.length})
          </h2>
          <div className="space-y-2">
            {interactions.map((it, i) => (
              <div
                key={i}
                className={`rounded-sm border px-3 py-2 ${SEVERITY_STYLES[it.severity]}`}
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
          <p className="text-[11px] text-alert/80 mt-3">
            Educational check only — always confirm with your doctor or pharmacist.
          </p>
        </div>
      )}

      <div className="mb-6">
        <Button onClick={() => setShowForm(!showForm)}>
          {showForm ? 'Cancel' : (
            <>
              <Plus className="w-4 h-4" /> Add Medicine
            </>
          )}
        </Button>
      </div>

      {showForm && (
        <Card className="p-lg mb-8">
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
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
            </div>

            <div className="flex flex-col gap-1.5 w-full">
              <label className="text-sm font-semibold text-on-surface">Taking Times</label>
              {takingTimes.map((t, i) => (
                <div key={i} className="flex items-center gap-2">
                  <input
                    type="time"
                    value={t}
                    onChange={(e) => updateTime(i, e.target.value)}
                    className="flex h-11 rounded-sm border border-outline bg-surface-card px-3.5 py-2 text-base text-on-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring"
                  />
                  {takingTimes.length > 1 && (
                    <button
                      type="button"
                      onClick={() => setTakingTimes(takingTimes.filter((_, x) => x !== i))}
                      className="text-alert text-sm hover:underline"
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
            <div className="flex gap-2">
              <Button type="submit">Add Medicine</Button>
              <Button type="button" variant="ghost" onClick={() => setShowForm(false)}>Cancel</Button>
            </div>
          </form>
        </Card>
      )}

      {medicines.length === 0 ? (
        <Card className="p-lg">
          <EmptyState
            icon={Pill}
            title="No medicines tracked yet"
            description="Add your first medicine and get a daily dose plan with reminders."
            action={<Button onClick={() => setShowForm(true)}>Add the first medicine</Button>}
          />
        </Card>
      ) : (
        <>
          {activeMeds.length > 0 && (
            <div className="mb-8">
              <h2 className="text-lg font-display font-semibold text-on-surface mb-4">
                Active ({activeMeds.length})
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {activeMeds.map((med) => renderMedicineCard(med, false))}
              </div>
            </div>
          )}
          {endedMeds.length > 0 && (
            <div>
              <h2 className="text-lg font-display font-semibold text-on-surface-variant mb-4">
                Ended ({endedMeds.length})
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {endedMeds.map((med) => renderMedicineCard(med, true))}
              </div>
            </div>
          )}
        </>
      )}
    </>
  );
}