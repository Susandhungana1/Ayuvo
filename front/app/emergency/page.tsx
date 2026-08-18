'use client';

import { useEffect, useState } from 'react';
import { apiFetch } from '@/lib/api';
import { useRouter } from 'next/navigation';
import { Phone } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

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

const SELECT_CLASS =
  'flex h-11 w-full rounded-sm border border-outline bg-surface-card px-3.5 text-base text-on-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring';

async function fetchProfile(): Promise<EmergencyProfile> {
  const token = localStorage.getItem('token');
  const res = await apiFetch(`${API_URL}/api/emergency/profile`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  if (!res.ok) throw new Error(`Could not load your emergency profile (HTTP ${res.status}).`);
  return await res.json();
}

export default function Emergency() {
  const router = useRouter();
  const [profile, setProfile] = useState<EmergencyProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [showContactForm, setShowContactForm] = useState(false);
  const [contactForm, setContactForm] = useState({ name: '', relationship: '', phone: '', email: '' });
  const [profileForm, setProfileForm] = useState({ blood_type: '', allergies: '', medical_conditions: '' });

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) { router.push('/auth/login'); return; }
    let cancelled = false;
    (async () => {
      try {
        const data = await fetchProfile();
        if (!cancelled) {
          setProfile(data);
          setProfileForm({
            blood_type: data.blood_type || '',
            allergies: data.allergies || '',
            medical_conditions: data.medical_conditions || '',
          });
        }
      } catch (err) { console.error(err);
      } finally { if (!cancelled) setLoading(false); }
    })();
    return () => { cancelled = true; };
  }, [router]);

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/emergency/profile`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          blood_type: profileForm.blood_type || null,
          allergies: profileForm.allergies || null,
          medical_conditions: profileForm.medical_conditions || null,
        })
      });
      if (res.ok) {
        const data = await res.json();
        setProfile(data);
        alert('Emergency profile saved!');
      } else {
        const err = await res.json();
        alert(err.detail || 'Failed to save');
      }
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Failed to save');
    }
  };

  const handleAddContact = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/emergency/contacts`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(contactForm)
      });
      if (res.ok) {
        setProfile(await fetchProfile());
        setShowContactForm(false);
        setContactForm({ name: '', relationship: '', phone: '', email: '' });
      } else {
        const err = await res.json();
        alert(err.detail || 'Failed to add contact');
      }
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Failed to add contact');
    }
  };

  const handleDeleteContact = async (id: string) => {
    if (!confirm('Remove this emergency contact?')) return;
    try {
      const token = localStorage.getItem('token');
      await apiFetch(`${API_URL}/api/emergency/contacts/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      setProfile(await fetchProfile());
    } catch (err) { console.error(err); }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-surface">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Skeleton className="h-9 w-72 mb-lg" />
          <Skeleton className="h-56 mb-lg" />
          <Skeleton className="h-40 mb-lg" />
          <Skeleton className="h-40" />
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-lg">
          <h1 className="text-2xl sm:text-3xl font-display font-bold text-on-surface">Emergency Medical ID</h1>
        </div>

        <Card className="mb-lg">
          <h2 className="text-lg sm:text-xl font-display font-semibold text-on-surface mb-lg">Medical Information</h2>
          <form onSubmit={handleSaveProfile} className="space-y-lg">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-lg">
              <div>
                <label className="text-sm font-semibold text-on-surface block mb-xs">Blood Type</label>
                <select value={profileForm.blood_type} onChange={e => setProfileForm({ ...profileForm, blood_type: e.target.value })}
                  className={SELECT_CLASS}>
                  <option value="">Select</option>
                  <option value="A+">A+</option>
                  <option value="A-">A-</option>
                  <option value="B+">B+</option>
                  <option value="B-">B-</option>
                  <option value="AB+">AB+</option>
                  <option value="AB-">AB-</option>
                  <option value="O+">O+</option>
                  <option value="O-">O-</option>
                </select>
              </div>
              <Input label="Allergies" name="allergies" value={profileForm.allergies}
                onChange={e => setProfileForm({ ...profileForm, allergies: e.target.value })}
                placeholder="e.g., Peanuts, Penicillin" />
              <Input label="Medical Conditions" name="conditions" value={profileForm.medical_conditions}
                onChange={e => setProfileForm({ ...profileForm, medical_conditions: e.target.value })}
                placeholder="e.g., Asthma, Diabetes" />
            </div>
            <Button type="submit">Save Medical Info</Button>
          </form>
        </Card>

        <Card className="mb-lg">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-md mb-lg">
            <h2 className="text-lg sm:text-xl font-display font-semibold text-on-surface">Emergency Contacts</h2>
            <Button onClick={() => setShowContactForm(!showContactForm)} className="w-full sm:w-auto">
              {showContactForm ? 'Cancel' : (
                <>
                  <Phone className="w-4 h-4" aria-hidden="true" />
                  Add Contact
                </>
              )}
            </Button>
          </div>

          {showContactForm && (
            <form onSubmit={handleAddContact} className="space-y-lg mb-xl p-lg bg-outline/10 rounded-md">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-lg">
                <Input label="Full Name" name="name" value={contactForm.name}
                  onChange={e => setContactForm({ ...contactForm, name: e.target.value })} required />
                <Input label="Relationship" name="rel" value={contactForm.relationship}
                  onChange={e => setContactForm({ ...contactForm, relationship: e.target.value })} required
                  placeholder="Spouse, Parent, Sibling" />
                <Input label="Phone Number" name="phone" value={contactForm.phone}
                  onChange={e => setContactForm({ ...contactForm, phone: e.target.value })} required />
                <Input label="Email (optional)" name="email" type="email" value={contactForm.email}
                  onChange={e => setContactForm({ ...contactForm, email: e.target.value })} />
              </div>
              <Button type="submit">Add Contact</Button>
            </form>
          )}

          {(!profile || profile.emergency_contacts.length === 0) ? (
            <p className="text-on-surface-variant text-center py-lg">No emergency contacts added yet</p>
          ) : (
            <div className="space-y-md">
              {profile.emergency_contacts.map(c => (
                <div key={c.id} className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-sm p-lg bg-outline/10 rounded-md">
                  <div className="min-w-0">
                    <p className="font-medium text-on-surface truncate">{c.name}</p>
                    <p className="text-sm text-on-surface-variant truncate">{c.relationship} | {c.phone}</p>
                    {c.email && <p className="text-sm text-on-surface-variant truncate">{c.email}</p>}
                  </div>
                  <button onClick={() => handleDeleteContact(c.id)} className="text-alert text-sm hover:underline self-start sm:self-auto">Remove</button>
                </div>
              ))}
            </div>
          )}
        </Card>

        <Card className="mb-lg">
          <h2 className="text-lg sm:text-xl font-display font-semibold text-on-surface mb-lg">Preview - Emergency ID Card</h2>
          {/* Emergency ID is a mock printed card: keep it a fixed high-contrast
              light-red card with dark-red text in BOTH light and dark themes.
              Colors are inline so they never depend on inherited theme tokens
              or the global .dark utility overrides. */}
          <div className="p-lg sm:p-xl rounded-md max-w-md mx-auto" style={{ backgroundColor: '#fef2f2', border: '2px solid #fca5a5', color: '#7f1d1d' }}>
            <div className="text-center mb-lg">
              <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-xs" style={{ backgroundColor: '#fee2e2' }}>
                <svg className="w-6 h-6" style={{ color: '#dc2626' }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4.5c-.77-.833-1.964-.833-2.732 0L4.068 16.5c-.77.833.192 2.5 1.732 2.5z" />
                </svg>
              </div>
              <h3 className="text-lg font-bold" style={{ color: '#991b1b' }}>EMERGENCY MEDICAL ID</h3>
            </div>
            <div className="space-y-sm text-sm" style={{ color: '#7f1d1d' }}>
              <div className="flex justify-between"><span className="font-medium">Blood Type:</span> <span className="font-bold" style={{ color: '#b91c1c' }}>{profileForm.blood_type || 'Not set'}</span></div>
              <div className="flex justify-between"><span className="font-medium">Allergies:</span> <span>{profileForm.allergies || 'None listed'}</span></div>
              <div className="flex justify-between"><span className="font-medium">Conditions:</span> <span>{profileForm.medical_conditions || 'None listed'}</span></div>
            </div>
            {profile && profile.emergency_contacts.length > 0 && (
              <div className="mt-lg pt-lg" style={{ borderTop: '1px solid #fca5a5' }}>
                <p className="text-xs font-medium mb-sm" style={{ color: '#b91c1c' }}>EMERGENCY CONTACTS</p>
                {profile.emergency_contacts.map(c => (
                  <p key={c.id} className="text-xs" style={{ color: '#7f1d1d' }}>{c.name} ({c.relationship}): {c.phone}</p>
                ))}
              </div>
            )}
          </div>
          <p className="text-xs text-on-surface-variant text-center mt-lg">
            These details (blood type, allergies, conditions and your contacts)
            ride along with your all-reports QR — generate it under Share
            Records and anyone who scans it sees them.
          </p>
        </Card>
      </div>
    </div>
  );
}