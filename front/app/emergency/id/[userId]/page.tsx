'use client';

import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';

const API_URL = 'http://127.0.0.1:3001';

interface EmergencyContact {
  id: string;
  name: string;
  relationship: string;
  phone: string;
  email: string | null;
}

interface EmergencyProfile {
  blood_type: string | null;
  allergies: string | null;
  medical_conditions: string | null;
  emergency_contacts: EmergencyContact[];
}

export default function PublicEmergencyId() {
  const params = useParams();
  const userId = params?.userId as string;
  const [profile, setProfile] = useState<EmergencyProfile | null>(null);
  const [status, setStatus] = useState<'loading' | 'ok' | 'error'>('loading');

  useEffect(() => {
    if (!userId) return;
    // Next.js decodes the route param, so userId here is the raw id (e.g.
    // "#hos013"); re-encode it for the API path.
    fetch(`${API_URL}/api/emergency/public/${encodeURIComponent(userId)}`)
      .then(async (res) => {
        if (!res.ok) throw new Error('not found');
        return res.json();
      })
      .then((data) => { setProfile(data); setStatus('ok'); })
      .catch(() => setStatus('error'));
  }, [userId]);

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#7f1d1d', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
      <div style={{ width: '100%', maxWidth: 440 }}>
        <div style={{ backgroundColor: '#fef2f2', border: '3px solid #dc2626', borderRadius: 16, overflow: 'hidden', boxShadow: '0 10px 40px rgba(0,0,0,0.3)' }}>
          <div style={{ backgroundColor: '#dc2626', color: '#fff', padding: '16px 20px', textAlign: 'center' }}>
            <div style={{ fontSize: 13, letterSpacing: 2, fontWeight: 700, opacity: 0.9 }}>EMERGENCY MEDICAL ID</div>
            <div style={{ fontSize: 12, marginTop: 2, opacity: 0.85 }}>MediStore</div>
          </div>

          <div style={{ padding: 20, color: '#7f1d1d' }}>
            {status === 'loading' && <p style={{ textAlign: 'center' }}>Loading…</p>}
            {status === 'error' && (
              <p style={{ textAlign: 'center', color: '#991b1b' }}>
                This emergency ID is unavailable or the link is invalid.
              </p>
            )}
            {status === 'ok' && profile && (
              <>
                <Row label="Blood Type" value={profile.blood_type || 'Not set'} highlight />
                <Row label="Allergies" value={profile.allergies || 'None listed'} />
                <Row label="Conditions" value={profile.medical_conditions || 'None listed'} />

                <div style={{ marginTop: 16, paddingTop: 16, borderTop: '1px solid #fca5a5' }}>
                  <div style={{ fontSize: 11, fontWeight: 700, color: '#b91c1c', letterSpacing: 1, marginBottom: 8 }}>
                    EMERGENCY CONTACTS
                  </div>
                  {profile.emergency_contacts.length === 0 ? (
                    <p style={{ fontSize: 13 }}>None listed</p>
                  ) : (
                    profile.emergency_contacts.map((c) => (
                      <div key={c.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, padding: '6px 0' }}>
                        <span style={{ fontSize: 13 }}>
                          <strong>{c.name}</strong> <span style={{ opacity: 0.75 }}>({c.relationship})</span>
                        </span>
                        <a href={`tel:${c.phone}`} style={{ fontSize: 13, fontWeight: 700, color: '#dc2626', textDecoration: 'none', whiteSpace: 'nowrap' }}>
                          {c.phone}
                        </a>
                      </div>
                    ))
                  )}
                </div>
              </>
            )}
          </div>
        </div>
        <p style={{ textAlign: 'center', color: '#fecaca', fontSize: 11, marginTop: 12 }}>
          Public emergency information · no login required
        </p>
      </div>
    </div>
  );
}

function Row({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, padding: '6px 0', fontSize: 14 }}>
      <span style={{ fontWeight: 600 }}>{label}:</span>
      <span style={{ textAlign: 'right', fontWeight: highlight ? 800 : 400, color: highlight ? '#b91c1c' : '#7f1d1d', fontSize: highlight ? 18 : 14 }}>
        {value}
      </span>
    </div>
  );
}
