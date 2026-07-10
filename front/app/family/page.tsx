'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Input } from '@/components/input';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface Dependent {
  id: string;
  name: string;
  relationship: string;
  date_of_birth: string | null;
  blood_type: string | null;
  allergies: string | null;
  medical_conditions: string | null;
  notes: string | null;
}

const BLANK = {
  name: '',
  relationship: '',
  date_of_birth: '',
  blood_type: '',
  allergies: '',
  medical_conditions: '',
  notes: '',
};

export default function Family() {
  const router = useRouter();
  const [dependents, setDependents] = useState<Dependent[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState({ ...BLANK });

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) { router.push('/auth/login'); return; }
    fetchDependents();
  }, [router]);

  const fetchDependents = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/family`, {
        headers: { 'Authorization': `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setDependents(data.dependents || []);
      }
    } catch (err) { console.error(err); }
    finally { setLoading(false); }
  };

  const openAdd = () => {
    setEditingId(null);
    setForm({ ...BLANK });
    setShowForm(true);
  };

  const openEdit = (d: Dependent) => {
    setEditingId(d.id);
    setForm({
      name: d.name,
      relationship: d.relationship,
      date_of_birth: d.date_of_birth || '',
      blood_type: d.blood_type || '',
      allergies: d.allergies || '',
      medical_conditions: d.medical_conditions || '',
      notes: d.notes || '',
    });
    setShowForm(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('token');
      const payload = {
        name: form.name,
        relationship: form.relationship,
        date_of_birth: form.date_of_birth || null,
        blood_type: form.blood_type || null,
        allergies: form.allergies || null,
        medical_conditions: form.medical_conditions || null,
        notes: form.notes || null,
      };
      const url = editingId ? `${API_URL}/api/family/${editingId}` : `${API_URL}/api/family`;
      const res = await fetch(url, {
        method: editingId ? 'PUT' : 'POST',
        headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      if (res.ok) {
        setShowForm(false);
        setEditingId(null);
        setForm({ ...BLANK });
        fetchDependents();
      } else {
        const err = await res.json();
        alert(err.detail || 'Failed to save');
      }
    } catch (err: any) { alert(err.message); }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Remove this family member?')) return;
    try {
      const token = localStorage.getItem('token');
      await fetch(`${API_URL}/api/family/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` },
      });
      fetchDependents();
    } catch (err) { console.error(err); }
  };

  if (loading) {
    return <div className="min-h-screen bg-background flex items-center justify-center"><p className="text-subtext">Loading...</p></div>;
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-6">
          <h1 className="text-2xl sm:text-3xl font-bold text-text-main">Family &amp; Caregiver</h1>
          <p className="text-subtext text-sm mt-1">Keep basic medical profiles for children, elderly parents, or anyone you care for.</p>
        </div>

        <div className="mb-6">
          <Button onClick={showForm ? () => setShowForm(false) : openAdd}>
            {showForm ? 'Cancel' : '+ Add Family Member'}
          </Button>
        </div>

        {showForm && (
          <Card className="p-4 sm:p-6 mb-8">
            <h2 className="text-lg font-semibold text-text-main mb-4">{editingId ? 'Edit' : 'Add'} Family Member</h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <Input label="Full Name" name="name" value={form.name}
                  onChange={e => setForm({ ...form, name: e.target.value })} required />
                <Input label="Relationship" name="relationship" value={form.relationship}
                  onChange={e => setForm({ ...form, relationship: e.target.value })} required
                  placeholder="Child, Parent, Spouse" />
                <Input label="Date of Birth" name="dob" type="date" value={form.date_of_birth}
                  onChange={e => setForm({ ...form, date_of_birth: e.target.value })} />
                <div>
                  <label className="text-sm font-medium text-gray-700 block mb-1">Blood Type</label>
                  <select value={form.blood_type} onChange={e => setForm({ ...form, blood_type: e.target.value })}
                    className="flex h-10 w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm">
                    <option value="">Select</option>
                    {['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map(bt => (
                      <option key={bt} value={bt}>{bt}</option>
                    ))}
                  </select>
                </div>
                <Input label="Allergies" name="allergies" value={form.allergies}
                  onChange={e => setForm({ ...form, allergies: e.target.value })}
                  placeholder="e.g., Peanuts, Penicillin" />
                <Input label="Medical Conditions" name="conditions" value={form.medical_conditions}
                  onChange={e => setForm({ ...form, medical_conditions: e.target.value })}
                  placeholder="e.g., Asthma" />
              </div>
              <div className="flex flex-col gap-1.5 w-full">
                <label className="text-sm font-medium text-gray-700">Notes</label>
                <textarea value={form.notes} onChange={e => setForm({ ...form, notes: e.target.value })}
                  placeholder="Medications, doctor, insurance, etc."
                  className="flex w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
                  rows={3} />
              </div>
              <Button type="submit">{editingId ? 'Save Changes' : 'Add Family Member'}</Button>
            </form>
          </Card>
        )}

        {dependents.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext mb-4">No family members added yet</p>
            <Button onClick={openAdd}>Add Your First Family Member</Button>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {dependents.map(d => (
              <Card key={d.id} className="p-6">
                <div className="flex justify-between items-start mb-2">
                  <div className="min-w-0">
                    <h3 className="text-lg font-semibold text-text-main truncate">{d.name}</h3>
                    <p className="text-sm text-subtext">{d.relationship}</p>
                  </div>
                  {d.blood_type && (
                    <span className="px-2 py-1 text-xs rounded-full bg-red-100 text-red-700 font-semibold shrink-0">{d.blood_type}</span>
                  )}
                </div>
                <div className="space-y-1 text-sm text-subtext mt-3">
                  {d.date_of_birth && <p><span className="font-medium text-text-main">DOB:</span> {d.date_of_birth}</p>}
                  {d.allergies && <p><span className="font-medium text-text-main">Allergies:</span> {d.allergies}</p>}
                  {d.medical_conditions && <p><span className="font-medium text-text-main">Conditions:</span> {d.medical_conditions}</p>}
                  {d.notes && <p className="italic">{d.notes}</p>}
                </div>
                <div className="flex items-center gap-4 mt-4">
                  <button onClick={() => openEdit(d)} className="text-primary text-sm font-medium hover:underline">Edit</button>
                  <button onClick={() => handleDelete(d.id)} className="text-red-500 text-sm hover:underline">Remove</button>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
