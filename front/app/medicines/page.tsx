'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Input } from '@/components/input';

const API_URL = 'http://127.0.0.1:3001';

interface Medicine {
  id: string;
  name: string;
  dosage: string;
  frequency: string;
  start_date: string;
  end_date?: string;
  notes?: string;
}

export default function Medicines() {
  const router = useRouter();
  const [medicines, setMedicines] = useState<Medicine[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    dosage: '',
    frequency: '',
    start_date: '',
    end_date: '',
    notes: ''
  });

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    fetchMedicines();
  }, [router]);

  const fetchMedicines = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/medicines`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setMedicines(data.medicines || []);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
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
          notes: formData.notes || null
        })
      });
      if (res.ok) {
        const newMedicine = await res.json();
        setMedicines([newMedicine, ...medicines]);
        setShowForm(false);
        setFormData({ name: '', dosage: '', frequency: '', start_date: '', end_date: '', notes: '' });
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
      }
    } catch (err) {
      console.error(err);
    }
  };

  if (loading) {
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
          <Button onClick={() => setShowForm(!showForm)}>
            {showForm ? 'Cancel' : '+ Add Medicine'}
          </Button>
        </div>

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
            {medicines.map((med) => (
              <Card key={med.id} className="p-6">
                <h3 className="text-lg font-semibold text-text-main mb-2">{med.name}</h3>
                <p className="text-subtext text-sm mb-1">Dosage: {med.dosage}</p>
                <p className="text-subtext text-sm mb-1">Frequency: {med.frequency}</p>
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
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
