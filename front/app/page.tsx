'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import {
  AlertTriangle,
  CalendarDays,
  CheckCircle2,
  FileText,
  Flame,
  FolderOpen,
  HeartPulse,
  Pill,
  QrCode,
  RefreshCw,
  ScanLine,
  Stethoscope,
  type LucideIcon,
} from 'lucide-react';
import { apiFetch, API_URL } from '@/lib/api';
import { parseServerUtc } from '@/lib/datetime';
import { analyzeBP, analyzeHR, analyzeSugar, analyzeSpO2, analyzeTemp, type VitalBand } from '@/lib/status';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Skeleton } from '@/components/ui/skeleton';

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

type User = { name?: string; role?: string; id?: string };

/** One medicine at one time on one day — mirrors `DoseSchedule` in the app. */
interface DoseSlot {
  medicineId: string;
  name: string;
  dosage: string;
  time: string;
  at: Date;
  key: string;
}

const pad = (n: number) => String(n).padStart(2, '0');

/** Local calendar day, never `toISOString()` — that is UTC and shifts the day. */
const dayKey = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

function parseTimes(raw?: string): string[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((t): t is string => typeof t === 'string') : [];
  } catch {
    return [];
  }
}

/** `"08:00"` → minutes past midnight, or null if it is not a clock time. */
function minutesOf(hhmm: string): number | null {
  const parts = hhmm.split(':');
  if (parts.length < 2) return null;
  const h = Number(parts[0]);
  const m = Number(parts[1]);
  if (!Number.isFinite(h) || !Number.isFinite(m)) return null;
  return h * 60 + m;
}

/** `"14:30"` → `"2:30 PM"`, in the reader's own clock convention. */
function clockLabel(hhmm: string): string {
  const minutes = minutesOf(hhmm);
  if (minutes === null) return hhmm;
  return new Date(2000, 0, 1, Math.floor(minutes / 60), minutes % 60)
    .toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
}

/** Every dose scheduled on `day`, ordered by time. */
function slotsForDay(medicines: Medicine[], day: Date): DoseSlot[] {
  const key = dayKey(day);
  const slots: DoseSlot[] = [];
  for (const med of medicines) {
    if (med.start_date > key || (med.end_date && med.end_date < key)) continue;
    for (const time of parseTimes(med.taking_times)) {
      const minutes = minutesOf(time);
      if (minutes === null) continue;
      slots.push({
        medicineId: med.id,
        name: med.name,
        dosage: med.dosage,
        time,
        at: new Date(day.getFullYear(), day.getMonth(), day.getDate(), Math.floor(minutes / 60), minutes % 60),
        key: `${med.id}-${time}@${key}`,
      });
    }
  }
  return slots.sort((a, b) => a.at.getTime() - b.at.getTime() || a.name.localeCompare(b.name));
}

/** `2 hours ago` — the activity feed's only timestamp format. */
function ago(when: Date, now: Date): string {
  const mins = Math.floor((now.getTime() - when.getTime()) / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins} min ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs} hour${hrs === 1 ? '' : 's'} ago`;
  const days = Math.floor(hrs / 24);
  if (days < 7) return `${days} day${days === 1 ? '' : 's'} ago`;
  return when.toLocaleDateString('en-US', { day: 'numeric', month: 'short' });
}

/** `in 4h 20m` — deliberately coarse, so nobody watches it tick. */
function until(ms: number): string {
  const mins = Math.max(0, Math.round(ms / 60000));
  if (mins < 1) return 'now';
  if (mins < 60) return `in ${mins} min`;
  const hrs = Math.floor(mins / 60);
  const rest = mins % 60;
  if (hrs < 24) return rest === 0 ? `in ${hrs}h` : `in ${hrs}h ${rest}m`;
  return `in ${Math.floor(hrs / 24)}d`;
}

/** A date wearing a datetime's clothes: the time part is dropped, not shifted. */
function reportDateLabel(raw?: string | null): string {
  if (!raw) return 'Undated';
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(raw.trim());
  if (!match) return raw;
  const [, y, m, d] = match;
  return new Date(Number(y), Number(m) - 1, Number(d))
    .toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' });
}

/**
 * Three status colours, not one per band — DESIGN.md §2.5. Colour says how
 * urgent; the band name stays as text beside it, so colour is never the only
 * indicator.
 */
const LEVEL_DOT: Record<VitalBand['level'], string> = {
  ok: 'bg-[var(--color-ok)]',
  caution: 'bg-[var(--color-caution)]',
  alert: 'bg-[var(--color-alert)]',
};

const LEVEL_TEXT: Record<VitalBand['level'], string> = {
  ok: 'text-[var(--color-ok)]',
  caution: 'text-[var(--color-caution)]',
  alert: 'text-[var(--color-alert)]',
};

function greeting(now: Date): string {
  const hour = now.getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/**
 * The five things worth one tap from home. Reports are absent on purpose —
 * they have a section of their own directly below with its own "View all".
 */
const QUICK_ACTIONS: { label: string; href: string; icon: LucideIcon; hint: string }[] = [
  { label: 'Medicines', href: '/medicines', icon: Pill, hint: 'Doses and reminders' },
  { label: 'Scan report', href: '/reports#upload', icon: ScanLine, hint: 'Photo or PDF' },
  { label: 'Vitals', href: '/vitals', icon: HeartPulse, hint: 'Readings and trends' },
  { label: 'Appointments', href: '/appointments', icon: CalendarDays, hint: 'Book and track' },
  { label: 'Documents', href: '/documents', icon: FolderOpen, hint: 'Files and records' },
];

export default function Home() {
  const [user, setUser] = useState<User | null>(null);
  const [medicines, setMedicines] = useState<Medicine[]>([]);
  const [vitals, setVitals] = useState<VitalSign[]>([]);
  const [intakeLog, setIntakeLog] = useState<IntakeEntry[]>([]);
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [reports, setReports] = useState<Report[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  // `null` until mounted, so the server-rendered markup never contains a clock
  // the client would immediately disagree with.
  const [now, setNow] = useState<Date | null>(null);

  useEffect(() => {
    const tick = () => setNow(new Date());
    tick();
    const interval = window.setInterval(tick, 30000);
    return () => window.clearInterval(interval);
  }, []);

  useEffect(() => {
    const syncUser = () => {
      const token = localStorage.getItem('token');
      const userData = localStorage.getItem('user');
      setUser(token && userData ? (JSON.parse(userData) as User) : null);
    };
    syncUser();
    window.addEventListener('localStorageUpdated', syncUser);
    window.addEventListener('storage', syncUser);
    return () => {
      window.removeEventListener('localStorageUpdated', syncUser);
      window.removeEventListener('storage', syncUser);
    };
  }, []);

  const isDoctor = user?.role === 'DOCTOR';
  const isPatient = Boolean(user) && !isDoctor;

  const load = useCallback(async () => {
    const token = localStorage.getItem('token');
    if (!token) return;
    const auth = { headers: { Authorization: `Bearer ${token}` } };

    const get = async <T,>(path: string, pick: (data: Record<string, unknown>) => T, fallback: T): Promise<T> => {
      try {
        const res = await apiFetch(`${API_URL}${path}`, auth);
        if (!res.ok) return fallback;
        return pick(await res.json());
      } catch (e) {
        console.error(e);
        return fallback;
      }
    };

    const [meds, vits, intakes, appts, reps] = await Promise.all([
      get('/api/medicines', (d) => (d.medicines as Medicine[]) ?? [], [] as Medicine[]),
      get('/api/vitals?limit=20', (d) => (d.vitals as VitalSign[]) ?? [], [] as VitalSign[]),
      get('/api/medicines/intake/log?limit=200', (d) => (d.intakes as IntakeEntry[]) ?? [], [] as IntakeEntry[]),
      get('/api/appointments', (d) => (d.appointments as Appointment[]) ?? [], [] as Appointment[]),
      // Five, not one: the reports card shows three and the "View all" link
      // needs to know whether there is anything behind it.
      get('/api/reports?offset=0&limit=5', (d) => (d.reports as Report[]) ?? [], [] as Report[]),
    ]);

    setMedicines(meds);
    setVitals(vits);
    setIntakeLog(intakes);
    setAppointments(appts);
    setReports(reps);
  }, []);

  useEffect(() => {
    if (!isPatient) return;
    let cancelled = false;
    // `load` is async: every setState inside it runs in a promise callback,
    // after the first await, not synchronously in this effect body.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    load().finally(() => {
      if (!cancelled) setLoaded(true);
    });
    return () => {
      cancelled = true;
    };
  }, [isPatient, load]);

  // Derived, not stored: a doctor or a signed-out visitor never loads at all,
  // and deriving keeps setState out of the effect body.
  const loading = isPatient && !loaded;

  // Live: a dose marked taken from the alarm, or the tab coming back to the
  // front after it fired somewhere else, both re-read the intake log.
  useEffect(() => {
    if (!isPatient) return;
    const resync = () => {
      if (document.visibilityState === 'visible') load();
    };
    window.addEventListener('medicineIntakeRecorded', load);
    document.addEventListener('visibilitychange', resync);
    return () => {
      window.removeEventListener('medicineIntakeRecorded', load);
      document.removeEventListener('visibilitychange', resync);
    };
  }, [isPatient, load]);

  const refresh = async () => {
    setRefreshing(true);
    try {
      await load();
      setNow(new Date());
    } finally {
      setRefreshing(false);
    }
  };

  /** Every dose slot already marked taken, keyed the way `slotsForDay` keys. */
  const takenKeys = useMemo(() => {
    const keys = new Set<string>();
    for (const entry of intakeLog) {
      if (entry.status !== 'taken') continue;
      const recorded = parseServerUtc(entry.recorded_at);
      if (!recorded) continue;
      keys.add(`${entry.medicine_id}-${entry.scheduled_time}@${dayKey(recorded)}`);
    }
    return keys;
  }, [intakeLog]);

  const today = useMemo(() => (now ? slotsForDay(medicines, now) : []), [medicines, now]);

  const overdue = useMemo(
    () => (now ? today.filter((s) => s.at < now && !takenKeys.has(s.key)) : []),
    [today, takenKeys, now],
  );

  const takenToday = useMemo(() => today.filter((s) => takenKeys.has(s.key)).length, [today, takenKeys]);

  /** The next dose still ahead — today's if there is one, else tomorrow's first. */
  const nextDose = useMemo(() => {
    if (!now) return null;
    const ahead = today.find((s) => s.at >= now);
    if (ahead) return ahead;
    const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    return slotsForDay(medicines, tomorrow)[0] ?? null;
  }, [today, medicines, now]);

  const latestVital = vitals[0] ?? null;

  /**
   * Consecutive full days ending yesterday where every scheduled dose was
   * marked taken. Days with no schedule are neutral; today is excluded because
   * an unfinished day says nothing yet. Mirrors `_adherenceStreak` in
   * `home_screen.dart` so both platforms quote the same number.
   */
  const adherenceStreak = useMemo(() => {
    if (!now || medicines.length === 0) return 0;
    let streak = 0;
    for (let back = 1; back <= 30; back++) {
      const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - back);
      const slots = slotsForDay(medicines, day);
      if (slots.length === 0) continue;
      if (!slots.every((s) => takenKeys.has(s.key))) return streak;
      streak++;
    }
    return streak;
  }, [medicines, takenKeys, now]);

  /**
   * What has actually happened, newest first. Only events the API gives a real
   * timestamp for: doses marked taken, and appointments already attended.
   * Reports carry no upload time (`created_at` is not in the response), so
   * inventing one for them would be a lie — they have their own card above.
   */
  const activity = useMemo(() => {
    if (!now) return [] as { id: string; icon: LucideIcon; title: string; detail: string; at: Date; href: string }[];
    const names = new Map(medicines.map((m) => [m.id, m.name]));

    const doses = intakeLog
      .filter((e) => e.status === 'taken')
      .map((e) => ({ entry: e, at: parseServerUtc(e.recorded_at) }))
      .filter((e): e is { entry: IntakeEntry; at: Date } => e.at !== null && e.at <= now)
      .map(({ entry, at }) => ({
        id: `intake-${entry.medicine_id}-${entry.scheduled_time}-${entry.recorded_at}`,
        icon: CheckCircle2,
        title: `Took ${names.get(entry.medicine_id) ?? 'a medicine'}`,
        detail: `${clockLabel(entry.scheduled_time)} dose`,
        at,
        href: '/medicines',
      }));

    const attended = appointments
      .filter((a) => a.status?.toUpperCase() !== 'CANCELLED')
      .map((a) => ({ appt: a, at: new Date(a.appointment_date) }))
      .filter(({ at }) => !Number.isNaN(at.getTime()) && at <= now)
      .map(({ appt, at }) => ({
        id: `appt-${appt.id}`,
        icon: Stethoscope,
        title: appt.title,
        detail: appt.doctor_name || appt.hospital || 'Appointment',
        at,
        href: '/appointments',
      }));

    return [...doses, ...attended].sort((a, b) => b.at.getTime() - a.at.getTime()).slice(0, 5);
  }, [intakeLog, appointments, medicines, now]);

  const hasMedicines = medicines.length > 0;

  return (
    <div className="bg-[var(--color-background)]">
      {isDoctor ? (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="text-center max-w-xl mx-auto">
            <h1 className="text-3xl font-bold text-[var(--color-ink)] font-heading mb-3">Doctor Dashboard</h1>
            <p className="text-[var(--color-ink-variant)] mb-6">Manage your patient appointments and availability.</p>
            <Link href="/dashboard"><Button variant="primary">Go to Dashboard</Button></Link>
          </div>
        </div>
      ) : user ? (
        /* PATIENT HOME — one column, 720px, five sections, in priority order. */
        <div className="mx-auto w-full max-w-[720px] px-4 sm:px-6 py-8">
          <header className="mb-7 flex items-start justify-between gap-4">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[var(--color-primary)]">
                {now ? now.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }) : ' '}
              </p>
              <h1 className="mt-2 text-3xl font-bold leading-tight text-[var(--color-ink)] font-heading">
                {now ? greeting(now) : 'Hello'}, {user.name?.split(' ')[0] || 'there'}
              </h1>
            </div>
            <button
              type="button"
              onClick={refresh}
              disabled={refreshing}
              aria-label="Refresh your health data"
              className="mt-1 inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-[var(--radius-sm)] border border-[var(--color-outline-subtle)] bg-white text-[var(--color-ink-variant)] transition-colors hover:border-[var(--color-primary)] hover:text-[var(--color-primary)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-focus)] disabled:opacity-50 dark:bg-[var(--color-card)] dark:border-[var(--color-outline)]"
            >
              <RefreshCw className={`h-[18px] w-[18px] ${refreshing ? 'animate-spin' : ''}`} aria-hidden="true" />
            </button>
          </header>

          <div className="space-y-6">
            {/* 1 — HEALTH SUMMARY. What to do next, what is late, how it is going. */}
            {loading ? (
              <Card><Skeleton className="h-6 w-40" /><Skeleton className="mt-3 h-10 w-full" /><Skeleton className="mt-3 h-16 w-full" /></Card>
            ) : (
              <Card>
                {overdue.length > 0 && (
                  <div className="mb-5 rounded-[var(--radius-md)] border border-[var(--color-alert)] bg-[var(--color-alert-container)] p-4">
                    <div className="flex items-start gap-3">
                      <AlertTriangle className="mt-0.5 h-5 w-5 shrink-0 text-[var(--color-alert)]" aria-hidden="true" />
                      <div className="min-w-0">
                        <p className="text-sm font-semibold text-[var(--color-alert)]">
                          {overdue.length} dose{overdue.length === 1 ? '' : 's'} overdue today
                        </p>
                        <p className="mt-1 text-sm text-[var(--color-alert)]">
                          {overdue.slice(0, 3).map((s) => `${s.name} at ${clockLabel(s.time)}`).join(' · ')}
                          {overdue.length > 3 ? ` · and ${overdue.length - 3} more` : ''}
                        </p>
                        <Link
                          href="/medicines"
                          className="mt-3 inline-flex items-center gap-1 text-sm font-semibold text-[var(--color-alert)] underline underline-offset-4"
                        >
                          Mark them taken →
                        </Link>
                      </div>
                    </div>
                  </div>
                )}

                {!hasMedicines ? (
                  <div className="text-center">
                    <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-[var(--color-muted)] text-[var(--color-ink-variant)]">
                      <Pill className="h-6 w-6" aria-hidden="true" />
                    </div>
                    <h2 className="mt-4 text-lg font-semibold text-[var(--color-ink)] font-heading">No medicines yet</h2>
                    <p className="mt-1.5 text-sm text-[var(--color-ink-variant)]">Add your first medicine to get reminders</p>
                    <Link href="/medicines" className="mt-5 inline-block"><Button variant="primary">Add a medicine</Button></Link>
                  </div>
                ) : (
                  <>
                    <div className="flex flex-col gap-5 sm:flex-row sm:items-start sm:justify-between">
                      <div className="min-w-0">
                        <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-variant)]">
                          {nextDose && now && nextDose.at.getDate() !== now.getDate() ? 'Next dose · tomorrow' : 'Next dose'}
                        </p>
                        {nextDose && now ? (
                          <>
                            <h2 className="mt-2 truncate text-2xl font-bold text-[var(--color-ink)] font-heading">{nextDose.name}</h2>
                            <p className="mt-1 text-sm text-[var(--color-ink-variant)]">
                              <span className="font-semibold text-[var(--color-primary)] tabular-nums">{clockLabel(nextDose.time)}</span>
                              {' · '}{nextDose.dosage}{' · '}{until(nextDose.at.getTime() - now.getTime())}
                            </p>
                          </>
                        ) : (
                          <>
                            <h2 className="mt-2 text-2xl font-bold text-[var(--color-ink)] font-heading">Nothing scheduled</h2>
                            <p className="mt-1 text-sm text-[var(--color-ink-variant)]">
                              None of your medicines has a dose time set, so there is no schedule to count down to.
                            </p>
                          </>
                        )}
                      </div>

                      <div className="flex shrink-0 gap-3">
                        {today.length > 0 && (
                          <div className="min-w-[92px] rounded-[var(--radius-md)] border border-[var(--color-outline-subtle)] bg-[var(--color-muted)] px-3 py-2.5 dark:border-[var(--color-outline)]">
                            <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--color-ink-variant)]">Today</p>
                            <p className="mt-1 text-xl font-bold tabular-nums text-[var(--color-ink)] font-heading">
                              {takenToday}<span className="text-sm font-semibold text-[var(--color-ink-variant)]">/{today.length}</span>
                            </p>
                            <p className="text-[11px] text-[var(--color-ink-variant)]">doses taken</p>
                          </div>
                        )}
                        {adherenceStreak >= 2 && (
                          <div className="min-w-[92px] rounded-[var(--radius-md)] border border-[var(--color-ok-container)] bg-[var(--color-ok-container)] px-3 py-2.5">
                            <p className="inline-flex items-center gap-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--color-ok)]">
                              <Flame className="h-3 w-3" aria-hidden="true" />Streak
                            </p>
                            <p className="mt-1 text-xl font-bold tabular-nums text-[var(--color-ok)] font-heading">{adherenceStreak}d</p>
                            <p className="text-[11px] text-[var(--color-ok)]">all doses taken</p>
                          </div>
                        )}
                      </div>
                    </div>

                    {latestVital && (
                      <Link
                        href="/vitals"
                        className="pressed mt-5 block rounded-[var(--radius-md)] border border-[var(--color-outline-subtle)] bg-[var(--color-muted)] p-3 transition-colors hover:border-[var(--color-primary)] dark:border-[var(--color-outline)]"
                      >
                        <div className="flex items-center gap-5 overflow-x-auto">
                          {vitalReadings(latestVital).map((reading) => (
                            <div key={reading.label} className="shrink-0">
                              <p className="flex items-center gap-1.5 text-lg font-bold leading-tight tabular-nums text-[var(--color-ink)]">
                                <span className={`h-[7px] w-[7px] shrink-0 rounded-full ${LEVEL_DOT[reading.band.level]}`} aria-hidden="true" />
                                {reading.value}
                              </p>
                              {/* Normal stays quiet — the default state should not shout.
                                  Anything else is named, so the strip reads without colour. */}
                              <p className={`mt-0.5 text-xs ${reading.band.level === 'ok' ? 'text-[var(--color-ink-variant)]' : `font-semibold ${LEVEL_TEXT[reading.band.level]}`}`}>
                                {reading.label}
                                {reading.band.level !== 'ok' && ` · ${reading.band.label}`}
                              </p>
                            </div>
                          ))}
                        </div>
                      </Link>
                    )}
                  </>
                )}
              </Card>
            )}

            {/* 2 — QUICK ACTIONS. Everything core, one tap away. */}
            <nav aria-label="Quick actions">
              <div className="grid grid-cols-3 gap-3 sm:grid-cols-5">
                {QUICK_ACTIONS.map(({ label, href, icon: Icon, hint }) => (
                  <Link
                    key={label}
                    href={href}
                    className="pressed group flex min-h-[104px] flex-col items-center justify-center gap-2 rounded-[var(--radius-md)] border border-[var(--color-outline-subtle)] bg-white p-3 text-center transition-colors hover:border-[var(--color-primary)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-focus)] dark:bg-[var(--color-card)] dark:border-[var(--color-outline)]"
                    title={hint}
                  >
                    {/* The tile keeps its colours on hover: inverting to white
                        on primary reads fine in light mode and fails contrast
                        against the dark-mode primary. The card's border is the
                        hover affordance. */}
                    <span className="flex h-10 w-10 items-center justify-center rounded-[var(--radius-sm)] bg-[var(--color-primary-light)] text-[var(--color-primary)]">
                      <Icon className="h-5 w-5" aria-hidden="true" />
                    </span>
                    <span className="text-xs font-semibold leading-tight text-[var(--color-ink)]">{label}</span>
                  </Link>
                ))}
              </div>
            </nav>

            {/* 3 — REPORTS. The newest few, with the way to all of them. */}
            <Card>
              <div className="flex items-center justify-between gap-3">
                <h2 className="text-xl font-semibold text-[var(--color-ink)] font-heading">Recent reports</h2>
                <Link href="/reports" className="shrink-0 text-sm font-medium text-[var(--color-primary)] hover:underline">
                  View all →
                </Link>
              </div>

              {loading ? (
                <div className="mt-4 space-y-2"><Skeleton className="h-14 w-full" /><Skeleton className="h-14 w-full" /></div>
              ) : reports.length === 0 ? (
                <div className="mt-4 rounded-[var(--radius-md)] border border-dashed border-[var(--color-outline-subtle)] bg-[var(--color-muted)] p-6 text-center dark:border-[var(--color-outline)]">
                  <FileText className="mx-auto h-6 w-6 text-[var(--color-ink-variant)]" aria-hidden="true" />
                  <p className="mt-3 text-sm text-[var(--color-ink-variant)]">Scan or upload a lab report to see it here</p>
                  <Link href="/reports#upload" className="mt-4 inline-block"><Button variant="outline">Scan a report</Button></Link>
                </div>
              ) : (
                <ul className="mt-4 space-y-2">
                  {reports.slice(0, 3).map((report) => (
                    <li key={report.id}>
                      <Link
                        href="/reports"
                        className="pressed flex items-center gap-3 rounded-[var(--radius-md)] border border-[var(--color-outline-subtle)] bg-[var(--color-muted)] p-3 transition-colors hover:border-[var(--color-primary)] dark:border-[var(--color-outline)]"
                      >
                        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[var(--radius-sm)] bg-[var(--color-primary-light)] text-[var(--color-primary)]">
                          <FileText className="h-[18px] w-[18px]" aria-hidden="true" />
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-sm font-semibold capitalize text-[var(--color-ink)]">
                            {report.report_type.toLowerCase().replace(/_/g, ' ')}
                          </span>
                          <span className="block text-xs text-[var(--color-ink-variant)]">{reportDateLabel(report.report_date)}</span>
                        </span>
                        <span aria-hidden="true" className="text-[var(--color-ink-variant)]">›</span>
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
            </Card>

            {/* 4 — SHARE. The one thing a patient does *for someone else*, so it
                gets the page's only tinted card. No gradient: DESIGN.md §1. */}
            <Link
              href="/share"
              className="pressed block rounded-[var(--radius-lg)] border border-[var(--color-primary)] bg-[var(--color-primary-light)] p-5 transition-shadow hover:shadow-[var(--shadow-md)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-focus)] sm:p-6"
            >
              <div className="flex items-center gap-4">
                {/* Dark-on-white always: a QR inverted for dark mode does not scan. */}
                <span className="flex h-16 w-16 shrink-0 items-center justify-center rounded-[var(--radius-md)] bg-white text-[var(--color-ink)]">
                  <QrCode className="h-10 w-10" aria-hidden="true" />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-lg font-semibold text-[var(--color-ink)] font-heading">Share your health record</span>
                  <span className="mt-1 block text-sm text-[var(--color-ink-variant)]">
                    Show a QR code or send a read-only link to a doctor or caretaker.
                  </span>
                </span>
                <span aria-hidden="true" className="text-xl text-[var(--color-primary)]">›</span>
              </div>
            </Link>

            {/* 5 — ACTIVITY. Hidden entirely when there is none. */}
            {activity.length > 0 && (
              <section>
                <h2 className="mb-3 text-xl font-semibold text-[var(--color-ink)] font-heading">Recent activity</h2>
                <ul className="space-y-2">
                  {activity.map((item) => (
                    <li key={item.id}>
                      <Link
                        href={item.href}
                        className="pressed flex items-center gap-3 rounded-[var(--radius-md)] border border-[var(--color-outline-subtle)] bg-white p-3 transition-colors hover:border-[var(--color-primary)] dark:bg-[var(--color-card)] dark:border-[var(--color-outline)]"
                      >
                        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[var(--color-muted)] text-[var(--color-ink-variant)]">
                          <item.icon className="h-[18px] w-[18px]" aria-hidden="true" />
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-sm font-semibold text-[var(--color-ink)]">{item.title}</span>
                          <span className="block truncate text-xs text-[var(--color-ink-variant)]">{item.detail}</span>
                        </span>
                        <span className="shrink-0 text-xs text-[var(--color-ink-variant)]">{now ? ago(item.at, now) : ''}</span>
                      </Link>
                    </li>
                  ))}
                </ul>
              </section>
            )}
          </div>
        </div>
      ) : (
        /* PUBLIC LANDING PAGE — non-logged-in */
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-20 pb-16 text-center">
          <p className="text-sm text-[var(--color-primary)] font-medium mb-3">Secure &amp; Private</p>
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
                  <details key={item.q} className="group bg-[var(--color-muted)] dark:bg-[var(--color-background)] border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] rounded-[var(--radius-md)]">
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

/**
 * The latest reading as a short strip. Band classification comes from
 * `lib/status.ts` — the same engine as `/vitals` — so a threshold change is
 * edited once. Home only answers "am I OK?"; the detail lives one tap away.
 */
function vitalReadings(v: VitalSign): { label: string; value: string; band: VitalBand }[] {
  const out: { label: string; value: string; band: VitalBand }[] = [];
  if (v.blood_pressure_systolic && v.blood_pressure_diastolic) {
    out.push({
      label: 'BP',
      value: `${v.blood_pressure_systolic}/${v.blood_pressure_diastolic}`,
      band: analyzeBP(v.blood_pressure_systolic, v.blood_pressure_diastolic),
    });
  }
  if (v.heart_rate) out.push({ label: 'Heart', value: `${v.heart_rate}`, band: analyzeHR(v.heart_rate) });
  if (v.blood_sugar) out.push({ label: 'Sugar', value: `${Math.round(v.blood_sugar)}`, band: analyzeSugar(v.blood_sugar) });
  if (v.temperature) out.push({ label: 'Temp', value: `${v.temperature.toFixed(1)}°C`, band: analyzeTemp(v.temperature) });
  if (v.oxygen_saturation) out.push({ label: 'SpO₂', value: `${v.oxygen_saturation}%`, band: analyzeSpO2(v.oxygen_saturation) });
  return out;
}
