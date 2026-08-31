"use client";

/**
 * MedicineAlarm — app-wide medicine intake alarm.
 *
 * Mounted once in the root layout so reminders fire on ANY page (not just the
 * Medicines page). While the app is open/backgrounded it:
 *   - polls the user's medicines and watches the clock,
 *   - at each `taking_time` raises an alarm-grade notification (persistent,
 *     vibrating, with Taken / Snooze action buttons) via the service worker,
 *   - plays a looping alarm tone in the foreground until the user acts,
 *   - records "Taken" to the adherence log and reschedules "Snooze" for +10min.
 *
 * NOTE: a plain PWA cannot wake itself when fully closed — that reliability is
 * handled separately by server Web Push (Phase B). This covers open/background.
 */

import { useCallback, useEffect, useRef } from "react";
import { apiFetch, API_URL } from '@/lib/api';
import { listLinks, CareLink } from '@/lib/care';



const SNOOZE_MINUTES = 10;
const POLL_MEDICINES_MS = 5 * 60 * 1000; // refetch medicines every 5 min
const TICK_MS = 20 * 1000; // check the clock every 20s
const GRACE_MINUTES = 10; // fire a dose due within the last N min, not just now
const NOTIFIED_KEY = "medAlarm:notified"; // {date, keys[]} in localStorage

interface Medicine {
  id: string;
  name: string;
  dosage: string;
  start_date: string;
  end_date?: string;
  taking_times?: string;
  /** Set when this medicine belongs to a linked patient (caretaker view). */
  patient_name?: string;
  /** User id of the linked patient, needed for the intake API. */
  patient_id?: string;
}

function parseTimes(tt?: string): string[] {
  if (!tt) return [];
  try {
    const v = JSON.parse(tt);
    return Array.isArray(v) ? v : [];
  } catch {
    return [];
  }
}

function todayStr(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(
    d.getDate(),
  ).padStart(2, "0")}`;
}

// True if `scheduled` (HH:MM) falls within the last GRACE_MINUTES up to `now`.
// A window (not an exact-minute match) lets an app that was backgrounded or
// throttled for a few minutes still catch a dose it would otherwise skip.
function isDue(scheduled: string, now: Date): boolean {
  const [h, m] = scheduled.split(":").map(Number);
  if (Number.isNaN(h) || Number.isNaN(m)) return false;
  const delta = now.getHours() * 60 + now.getMinutes() - (h * 60 + m);
  return delta >= 0 && delta <= GRACE_MINUTES;
}

// --- de-dupe store (per calendar day, survives navigation & reloads) ---------
function loadNotified(today: string): Set<string> {
  try {
    const raw = localStorage.getItem(NOTIFIED_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed.date === today && Array.isArray(parsed.keys)) {
        return new Set(parsed.keys);
      }
    }
  } catch {
    /* ignore */
  }
  return new Set();
}

function saveNotified(today: string, keys: Set<string>) {
  try {
    localStorage.setItem(NOTIFIED_KEY, JSON.stringify({ date: today, keys: [...keys] }));
  } catch {
    /* ignore */
  }
}

// --- foreground alarm tone (Web Audio; best-effort, may be blocked) ----------
let audioCtx: AudioContext | null = null;
let toneTimer: ReturnType<typeof setInterval> | null = null;
let toneStop: ReturnType<typeof setTimeout> | null = null;

function beep() {
  try {
    if (!audioCtx) {
      const Ctx = window.AudioContext ||
        (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!Ctx) return;
      audioCtx = new Ctx();
    }
    if (audioCtx.state === "suspended") audioCtx.resume().catch(() => {});
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = "sine";
    osc.frequency.value = 880;
    gain.gain.setValueAtTime(0.0001, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.25, audioCtx.currentTime + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + 0.5);
    osc.connect(gain).connect(audioCtx.destination);
    osc.start();
    osc.stop(audioCtx.currentTime + 0.5);
  } catch {
    /* audio unavailable */
  }
}

function startAlarmTone() {
  stopAlarmTone();
  beep();
  toneTimer = setInterval(beep, 900);
  // Safety cap: never ring forever if the user never interacts.
  toneStop = setTimeout(stopAlarmTone, 60 * 1000);
}

function stopAlarmTone() {
  if (toneTimer) clearInterval(toneTimer);
  if (toneStop) clearTimeout(toneStop);
  toneTimer = null;
  toneStop = null;
}

async function showAlarm(
  med: { id: string; name: string; dosage: string; patient_name?: string; patient_id?: string },
  time: string,
  tag: string,
) {
  const title = "💊 Medicine Reminder";
  const body = med.patient_name
    ? `${med.patient_name}: Time to take ${med.name} (${med.dosage})`
    : `Time to take ${med.name} (${med.dosage})`;
  const options: NotificationOptions & {
    actions?: { action: string; title: string }[];
    vibrate?: number[];
    renotify?: boolean;
    requireInteraction?: boolean;
  } = {
    body,
    icon: "/icon-192.png",
    badge: "/icon-192.png",
    tag,
    renotify: true,
    requireInteraction: true,
    vibrate: [400, 200, 400, 200, 400],
    data: { medId: med.id, name: med.name, dosage: med.dosage, time, patient_name: med.patient_name, patient_id: med.patient_id },
    actions: [
      { action: "taken", title: "✓ Taken" },
      { action: "snooze", title: `Snooze ${SNOOZE_MINUTES}m` },
    ],
  };

  try {
    if ("serviceWorker" in navigator) {
      const reg = await navigator.serviceWorker.ready;
      await reg.showNotification(title, options as NotificationOptions);
      startAlarmTone();
      return;
    }
  } catch {
    /* fall through */
  }
  try {
    new Notification(title, options as NotificationOptions);
    startAlarmTone();
  } catch {
    /* notifications unavailable */
  }
}

async function recordIntake(
  medId: string,
  time: string,
  status: "taken" | "snoozed",
  patientId?: string,
) {
  try {
    const token = localStorage.getItem("token");
    if (!token) return;
    const qs = patientId ? `?patient_id=${encodeURIComponent(patientId)}` : "";
    await apiFetch(`${API_URL}/api/medicines/${medId}/intake${qs}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ scheduled_time: time, status }),
    });
  } catch {
    /* offline — adherence log is best-effort */
  }
}

// --- Web Push registration (closed-app reminders, Phase B) -------------------
function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(base64);
  const output = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) output[i] = raw.charCodeAt(i);
  return output;
}

// The VAPID public key we last subscribed with. Browsers do not expose which
// key an existing subscription was created under, so we remember it ourselves:
// if the server rotates its keypair, every old subscription is silently
// rejected by the push service (the classic "push worked, then stopped" bug)
// and the only fix is a brand-new subscription. When this stored key differs
// from the server's current one we tear the old subscription down and resubscribe.
const VAPID_KEY_STORE = "medpush:vapidKey";

export async function ensurePushSubscription(): Promise<boolean> {
  try {
    if (typeof window === "undefined") return false;
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) return false;
    if (!("Notification" in window) || Notification.permission !== "granted") return false;
    const token = localStorage.getItem("token");
    if (!token) return false;

    const keyRes = await fetch(`${API_URL}/api/push/vapid-public-key`);
    if (!keyRes.ok) return false;
    const { public_key: publicKey, enabled } = await keyRes.json();
    if (!enabled || !publicKey) return false; // push not configured on the server

    const reg = await navigator.serviceWorker.ready;
    let sub = await reg.pushManager.getSubscription();

    let lastKey: string | null = null;
    try {
      lastKey = localStorage.getItem(VAPID_KEY_STORE);
    } catch {
      /* private-mode storage — treated as "never subscribed" */
    }

    const keyChanged = lastKey !== null && lastKey !== publicKey;
    if (sub && keyChanged) {
      await sub.unsubscribe().catch(() => {});
      sub = null;
    }

    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(publicKey) as BufferSource,
      });
      try {
        localStorage.setItem(VAPID_KEY_STORE, publicKey);
      } catch {
        /* see above */
      }
    }

    const json = sub.toJSON();
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
    const res = await apiFetch(`${API_URL}/api/push/subscribe`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        endpoint: json.endpoint,
        keys: json.keys,
        timezone,
      }),
    });
    return res.ok;
  } catch {
    /* push is best-effort; the in-app alarm still works without it */
    return false;
  }
}

export function MedicineAlarm() {
  const medsRef = useRef<Medicine[]>([]);
  const snoozeTimers = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());

  const fetchMedicines = useCallback(async () => {
    const token = localStorage.getItem("token");
    if (!token) {
      medsRef.current = [];
      return;
    }
    try {
      // Fetch the user's own medicines.
      const res = await apiFetch(`${API_URL}/api/medicines`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      let allMeds: Medicine[] = [];
      if (res.ok) {
        const data = await res.json();
        allMeds = data.medicines || [];
      }

      // If the user is a caretaker, also fetch linked patients' medicines so
      // in-app alarms fire for them too.  Server Web Push already handles
      // closed-app reminders for caretakers; this covers the open/background
      // case where the service worker notification alone isn't enough.
      try {
        const links: CareLink[] = await listLinks("caretaker");
        const patientMeds = await Promise.all(
          links.map(async (link) => {
            const r = await apiFetch(
              `${API_URL}/api/medicines?patient_id=${encodeURIComponent(link.user_id)}`,
              { headers: { Authorization: `Bearer ${token}` } },
            );
            if (!r.ok) return [] as Medicine[];
            const d = await r.json();
            return (d.medicines || []).map((m: Medicine) => ({
              ...m,
              patient_name: link.name,
              patient_id: link.user_id,
            }));
          }),
        );
        for (const batch of patientMeds) allMeds.push(...batch);
      } catch {
        /* care feature unavailable or disabled — own medicines still work */
      }

      medsRef.current = allMeds;
    } catch {
      /* keep previous list */
    }
  }, []);

  const fireAlarm = useCallback(
    (med: Medicine, time: string, key: string) => {
      const today = todayStr(new Date());
      const notified = loadNotified(today);
      notified.add(key);
      saveNotified(today, notified);
      showAlarm(med, time, key);
    },
    [],
  );

  const checkNow = useCallback(() => {
    if (typeof window === "undefined") return;
    if (!("Notification" in window) || Notification.permission !== "granted") return;
    if (!localStorage.getItem("token")) return;

    const now = new Date();
    const today = todayStr(now);
    const notified = loadNotified(today);

    for (const med of medsRef.current) {
      if (med.end_date && med.end_date < today) continue;
      if (med.start_date && med.start_date > today) continue;

      for (const t of parseTimes(med.taking_times)) {
        const key = `${med.id}-${t}-${today}`;
        if (notified.has(key)) continue;
        if (isDue(t, now)) fireAlarm(med, t, key);
      }
    }
  }, [fireAlarm]);

  // Handle Taken / Snooze coming back from the service worker.
  useEffect(() => {
    if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return;

    const onMessage = (event: MessageEvent) => {
      const msg = event.data;
      if (!msg || typeof msg !== "object") return;
      if (msg.type !== "medicine-alarm-action") return;

      stopAlarmTone();
      const { action, medId, time, name, dosage, patient_name, patient_id } = msg;

      if (action === "taken") {
        recordIntake(medId, time, "taken", patient_id);
      } else if (action === "snooze") {
        recordIntake(medId, time, "snoozed", patient_id);
        // Re-alarm after the snooze window (client-side; lost if app is closed).
        const timerKey = `${medId}-${time}`;
        const existing = snoozeTimers.current.get(timerKey);
        if (existing) clearTimeout(existing);
        const timer = setTimeout(
          () => {
            snoozeTimers.current.delete(timerKey);
            showAlarm(
              { id: medId, name, dosage, patient_name, patient_id },
              time,
              `${medId}-${time}-snooze-${Date.now()}`,
            );
          },
          SNOOZE_MINUTES * 60 * 1000,
        );
        snoozeTimers.current.set(timerKey, timer);
      }
    };

    navigator.serviceWorker.addEventListener("message", onMessage);
    return () => navigator.serviceWorker.removeEventListener("message", onMessage);
  }, []);

  // Pick up a pending notification action from URL params (cold start).
  // When the SW opens /medicines?na=taken&medId=...&time=... there is no
  // open client to receive postMessage, so the action is encoded in the URL.
  useEffect(() => {
    if (typeof window === "undefined") return;
    const params = new URLSearchParams(window.location.search);
    const action = params.get("na");
    if (!action) return;

    const medId = params.get("medId") || "";
    const time = params.get("time") || "";
    const name = params.get("name") || "";
    const dosage = params.get("dosage") || "";

    // Strip the query params so a refresh doesn't re-fire the action.
    const clean = window.location.pathname;
    window.history.replaceState({}, "", clean);

    if (action === "taken" && medId && time) {
      recordIntake(medId, time, "taken");
    } else if (action === "snooze" && medId && time) {
      recordIntake(medId, time, "snoozed");
      const timerKey = `${medId}-${time}`;
      const existing = snoozeTimers.current.get(timerKey);
      if (existing) clearTimeout(existing);
      const timer = setTimeout(
        () => {
          snoozeTimers.current.delete(timerKey);
          showAlarm({ id: medId, name, dosage }, time, `${medId}-${time}-snooze-${Date.now()}`);
        },
        SNOOZE_MINUTES * 60 * 1000,
      );
      snoozeTimers.current.set(timerKey, timer);
    }
  }, []);

  // Poll medicines + tick the clock.
  useEffect(() => {
    fetchMedicines();
    ensurePushSubscription(); // register for closed-app reminders (Phase B)
    const medsInterval = setInterval(fetchMedicines, POLL_MEDICINES_MS);
    return () => clearInterval(medsInterval);
  }, [fetchMedicines]);

  useEffect(() => {
    checkNow();
    const tick = setInterval(checkNow, TICK_MS);
    return () => clearInterval(tick);
  }, [checkNow]);

  // Re-check when the tab regains focus (catches missed minutes while hidden)
  // and (re)register the push subscription — permission may have been granted
  // after mount, and iOS can silently drop a subscription that needs refreshing.
  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState === "visible") {
        checkNow();
        ensurePushSubscription();
      }
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => document.removeEventListener("visibilitychange", onVisible);
  }, [checkNow]);

  return null;
}
