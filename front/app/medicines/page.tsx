'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { MedicineManager } from '@/components/medicine-manager';
import { ensurePushSubscription } from '@/components/medicine-alarm';
import { API_URL, authHeaders } from '@/lib/care';

export default function Medicines() {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [remindersReady, setRemindersReady] = useState(false);
  const [remindersEnabled, setRemindersEnabled] = useState(false);
  const [reminderStatus, setReminderStatus] = useState('');
  const [enablingReminders, setEnablingReminders] = useState(false);

  // A push subscription granted once stays granted for the installed PWA, but
  // iOS silently drops the *subscription* over time, and the old code never
  // told the user reminders were already on — the button always read
  // "Enable & test reminders", so every reopen looked like reminders had been
  // turned off. On mount we re-register if permission is granted and show the
  // real state. The permission prompt itself still only happens on tap (iOS
  // ignores requestPermission outside a user gesture anyway).
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    setReady(true);
    (async () => {
      if (!('Notification' in window)) {
        setRemindersEnabled(false);
        setRemindersReady(true);
        return;
      }
      if (Notification.permission === 'granted') {
        // `serviceWorker.ready` can hang on iOS; never let the "Checking…"
        // state show forever when the worker is stuck.
        const subscribed = await Promise.race([
          ensurePushSubscription(),
          new Promise<boolean>((resolve) => setTimeout(() => resolve(false), 5000)),
        ]);
        setRemindersEnabled(subscribed);
      } else {
        setRemindersEnabled(false);
      }
      setRemindersReady(true);
    })();
  }, [router]);

  const sendTestReminder = async () => {
    setEnablingReminders(true);
    setReminderStatus('');
    try {
      const res = await fetch(`${API_URL}/api/push/test`, {
        method: 'POST',
        headers: authHeaders(),
      });
      if (!res.ok) {
        setReminderStatus('Could not send the test. Try again in a moment.');
        return;
      }
      const data = await res.json();
      if (data.sent > 0) {
        setReminderStatus(`✅ Test sent to ${data.sent} device(s) — check your lock screen.`);
      } else {
        setReminderStatus('No device received the test. Reopen the app from the Home Screen, then try again.');
      }
    } catch {
      setReminderStatus('Something went wrong sending the test. Please try again.');
    } finally {
      setEnablingReminders(false);
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
      setRemindersEnabled(true);
      await sendTestReminder();
    } catch {
      setReminderStatus('Something went wrong enabling reminders. Please try again.');
    } finally {
      setEnablingReminders(false);
    }
  };

  if (!ready) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-subtext">Loading...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-text-main">Medicines</h1>
        </div>

        <div className="mb-6">
          {!remindersReady ? (
            <p className="text-sm text-subtext">Checking reminders…</p>
          ) : remindersEnabled ? (
            <div className="flex flex-wrap items-center gap-3">
              <span className="inline-flex items-center gap-1.5 rounded-md border border-green-300 bg-green-50 px-3 py-2 text-sm font-medium text-green-700">
                ✅ Reminders are on for this device
              </span>
              <button
                type="button"
                onClick={sendTestReminder}
                disabled={enablingReminders}
                className="inline-flex items-center gap-1.5 rounded-md border border-primary/40 bg-primary/5 px-3 py-2 text-sm font-medium text-primary hover:bg-primary/10 disabled:opacity-60"
              >
                🔔 {enablingReminders ? 'Sending…' : 'Send test reminder'}
              </button>
            </div>
          ) : (
            <button
              type="button"
              onClick={enableAndTestReminders}
              disabled={enablingReminders}
              className="inline-flex items-center gap-1.5 rounded-md border border-primary/40 bg-primary/5 px-3 py-2 text-sm font-medium text-primary hover:bg-primary/10 disabled:opacity-60"
            >
              🔔 {enablingReminders ? 'Enabling…' : 'Enable & test reminders'}
            </button>
          )}
        </div>

        {reminderStatus && (
          <div className="mb-6 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2.5 text-sm text-blue-800">
            {reminderStatus}
          </div>
        )}

        <MedicineManager />
      </div>
    </div>
  );
}
