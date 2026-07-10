'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { QRCodeSVG } from 'qrcode.react';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Input } from '@/components/input';

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

export default function Emergency() {
  const router = useRouter();
  const [profile, setProfile] = useState<EmergencyProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [showContactForm, setShowContactForm] = useState(false);
  const [contactForm, setContactForm] = useState({ name: '', relationship: '', phone: '', email: '' });
  const [profileForm, setProfileForm] = useState({ blood_type: '', allergies: '', medical_conditions: '' });
  const [publicUrl, setPublicUrl] = useState('');
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) { router.push('/auth/login'); return; }
    try {
      const user = JSON.parse(localStorage.getItem('user') || '{}');
      // User IDs contain a leading '#' (e.g. "#hos013"), which is a URL
      // fragment delimiter — encode it so the link/QR resolve correctly.
      if (user.id) setPublicUrl(`${window.location.origin}/emergency/id/${encodeURIComponent(user.id)}`);
    } catch {}
    fetchProfile();
  }, [router]);

  const handleCopyLink = async () => {
    try {
      await navigator.clipboard.writeText(publicUrl);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch { /* clipboard unavailable */ }
  };

  const fetchProfile = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/emergency/profile`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setProfile(data);
        setProfileForm({
          blood_type: data.blood_type || '',
          allergies: data.allergies || '',
          medical_conditions: data.medical_conditions || '',
        });
      }
    } catch (err) { console.error(err);
    } finally { setLoading(false); }
  };

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/emergency/profile`, {
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
    } catch (err: any) { alert(err.message); }
  };

  const handleAddContact = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/emergency/contacts`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(contactForm)
      });
      if (res.ok) {
        fetchProfile();
        setShowContactForm(false);
        setContactForm({ name: '', relationship: '', phone: '', email: '' });
      } else {
        const err = await res.json();
        alert(err.detail || 'Failed to add contact');
      }
    } catch (err: any) { alert(err.message); }
  };

  const handleDeleteContact = async (id: string) => {
    if (!confirm('Remove this emergency contact?')) return;
    try {
      const token = localStorage.getItem('token');
      await fetch(`${API_URL}/api/emergency/contacts/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      fetchProfile();
    } catch (err) { console.error(err); }
  };

  if (loading) {
    return <div className="min-h-screen bg-background flex items-center justify-center"><p className="text-subtext">Loading...</p></div>;
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-text-main">Emergency Medical ID</h1>
        </div>

        <Card className="p-4 sm:p-6 mb-8">
          <h2 className="text-lg sm:text-xl font-semibold text-text-main mb-4">Medical Information</h2>
          <form onSubmit={handleSaveProfile} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="text-sm font-medium text-gray-700 block mb-1">Blood Type</label>
                <select value={profileForm.blood_type} onChange={e => setProfileForm({ ...profileForm, blood_type: e.target.value })}
                  className="flex h-10 w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm">
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

        <Card className="p-4 sm:p-6 mb-8">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-4">
            <h2 className="text-lg sm:text-xl font-semibold text-text-main">Emergency Contacts</h2>
            <Button onClick={() => setShowContactForm(!showContactForm)} className="w-full sm:w-auto">
              {showContactForm ? 'Cancel' : '+ Add Contact'}
            </Button>
          </div>

          {showContactForm && (
            <form onSubmit={handleAddContact} className="space-y-4 mb-6 p-4 bg-gray-50 rounded-lg">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
            <p className="text-subtext text-center py-4">No emergency contacts added yet</p>
          ) : (
            <div className="space-y-3">
              {profile.emergency_contacts.map(c => (
                <div key={c.id} className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-2 p-4 bg-gray-50 rounded-lg">
                  <div className="min-w-0">
                    <p className="font-medium text-text-main truncate">{c.name}</p>
                    <p className="text-sm text-subtext truncate">{c.relationship} | {c.phone}</p>
                    {c.email && <p className="text-sm text-subtext truncate">{c.email}</p>}
                  </div>
                  <button onClick={() => handleDeleteContact(c.id)} className="text-red-500 text-sm hover:underline self-start sm:self-auto">Remove</button>
                </div>
              ))}
            </div>
          )}
        </Card>

        <Card className="p-4 sm:p-6">
          <h2 className="text-lg sm:text-xl font-semibold text-text-main mb-4">Preview - Emergency ID Card</h2>
          {/* Emergency ID is a mock printed card: keep it a fixed high-contrast
              light-red card with dark-red text in BOTH light and dark themes.
              Colors are inline so they never depend on inherited theme tokens
              or the global .dark utility overrides. */}
          <div className="p-4 sm:p-6 rounded-xl max-w-md mx-auto" style={{ backgroundColor: '#fef2f2', border: '2px solid #fca5a5', color: '#7f1d1d' }}>
            <div className="text-center mb-4">
              <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-2" style={{ backgroundColor: '#fee2e2' }}>
                <svg className="w-6 h-6" style={{ color: '#dc2626' }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4.5c-.77-.833-1.964-.833-2.732 0L4.068 16.5c-.77.833.192 2.5 1.732 2.5z" />
                </svg>
              </div>
              <h3 className="text-lg font-bold" style={{ color: '#991b1b' }}>EMERGENCY MEDICAL ID</h3>
            </div>
            <div className="space-y-2 text-sm" style={{ color: '#7f1d1d' }}>
              <div className="flex justify-between"><span className="font-medium">Blood Type:</span> <span className="font-bold" style={{ color: '#b91c1c' }}>{profileForm.blood_type || 'Not set'}</span></div>
              <div className="flex justify-between"><span className="font-medium">Allergies:</span> <span>{profileForm.allergies || 'None listed'}</span></div>
              <div className="flex justify-between"><span className="font-medium">Conditions:</span> <span>{profileForm.medical_conditions || 'None listed'}</span></div>
            </div>
            {profile && profile.emergency_contacts.length > 0 && (
              <div className="mt-4 pt-4" style={{ borderTop: '1px solid #fca5a5' }}>
                <p className="text-xs font-medium mb-2" style={{ color: '#b91c1c' }}>EMERGENCY CONTACTS</p>
                {profile.emergency_contacts.map(c => (
                  <p key={c.id} className="text-xs" style={{ color: '#7f1d1d' }}>{c.name} ({c.relationship}): {c.phone}</p>
                ))}
              </div>
            )}
          </div>
          <p className="text-xs text-subtext text-center mt-4">
            This info can be accessed via the public emergency API. Share your user ID with healthcare providers.
          </p>
        </Card>

        <Card className="p-4 sm:p-6 mt-8">
          <h2 className="text-lg sm:text-xl font-semibold text-text-main mb-1">Emergency QR Code</h2>
          <p className="text-sm text-subtext mb-4">
            First responders can scan this to view your medical ID — no login needed. Print it and keep it in your wallet or on your phone case.
          </p>
          {publicUrl ? (
            <div className="flex flex-col sm:flex-row items-center gap-6">
              <div className="bg-white p-3 rounded-lg border border-gray-200 shrink-0">
                <QRCodeSVG value={publicUrl} size={160} level="M" />
              </div>
              <div className="flex-1 w-full min-w-0">
                <label className="text-xs font-medium text-subtext block mb-1">Public link</label>
                <div className="flex flex-col sm:flex-row gap-2">
                  <input
                    readOnly
                    value={publicUrl}
                    onFocus={(e) => e.target.select()}
                    className="flex-1 h-10 rounded-md border border-gray-300 bg-gray-50 px-3 text-sm min-w-0"
                  />
                  <Button type="button" onClick={handleCopyLink} className="w-full sm:w-auto">
                    {copied ? 'Copied!' : 'Copy Link'}
                  </Button>
                </div>
                <a
                  href={publicUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-block mt-3 text-sm text-primary hover:underline"
                >
                  Open public emergency ID →
                </a>
              </div>
            </div>
          ) : (
            <p className="text-sm text-subtext">Sign in again to generate your emergency QR code.</p>
          )}
        </Card>
      </div>
    </div>
  );
}
