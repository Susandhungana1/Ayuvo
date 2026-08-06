'use client';

import { useEffect, useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Input } from '@/components/input';
import { formatPlainDate } from '@/lib/datetime';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface Document {
  id: string;
  hospital: string;
  location?: string;
  doctor_name?: string;
  department?: string;
  description?: string;
  checkup_date: string;
  files?: { id: string; name: string; file_type: string }[];
}

interface FileInfo {
  id: string;
  name: string;
  file_type: string;
}

export default function Documents() {
  const router = useRouter();
  const [documents, setDocuments] = useState<Document[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [expandedDoc, setExpandedDoc] = useState<string | null>(null);
  const [docFiles, setDocFiles] = useState<Record<string, FileInfo[]>>({});
  const [viewingFile, setViewingFile] = useState<{url: string; name: string} | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  const [formData, setFormData] = useState({
    hospital: '',
    location: '',
    doctor_name: '',
    department: '',
    description: '',
    checkup_date: ''
  });
  const [error, setError] = useState('');

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    fetchDocuments();
  }, [router]);

  const fetchDocuments = async () => {
    setLoading(true);
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    
try {
      const res = await fetch(`${API_URL}/api/documents`, {
        headers: { 
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json'
        }
      });
      
      if (res.ok) {
        const data = await res.json();
        setDocuments(data.documents || []);
      }
    } catch (err) {
      console.error('Fetch error:', err);
    }
    setLoading(false);
  };

  const fetchDocumentFiles = async (docId: string) => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/documents/${docId}/files`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        return data.files || [];
      }
    } catch (err) {
      console.error(err);
    }
    return [];
  };

  const toggleDocExpand = async (docId: string) => {
    if (expandedDoc === docId) {
      setExpandedDoc(null);
    } else {
      setExpandedDoc(docId);
      if (!docFiles[docId]) {
        const files = await fetchDocumentFiles(docId);
        setDocFiles(prev => ({ ...prev, [docId]: files }));
      }
    }
  };

  // Attachments are auth-gated binaries. Putting the API URL straight into an
  // <img>/<iframe> src sends no Authorization header, so the browser gets a 401
  // and renders a broken image — which is what this did. Fetch the bytes with
  // the header and hand the element a blob URL instead.
  const handleViewFile = async (docId: string, fileId: string, fileName: string) => {
    setError('');
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(
        `${API_URL}/api/documents/${docId}/files/${fileId}?inline=true`,
        { headers: { 'Authorization': `Bearer ${token}` } }
      );
      if (!res.ok) {
        setError(`Could not open ${fileName} (HTTP ${res.status}).`);
        return;
      }
      const blob = await res.blob();
      setViewingFile({ url: URL.createObjectURL(blob), name: fileName });
    } catch {
      setError(`Could not open ${fileName}. Check your connection and try again.`);
    }
  };

  const closeViewer = () => {
    if (viewingFile) URL.revokeObjectURL(viewingFile.url);
    setViewingFile(null);
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setSelectedFile(e.target.files[0]);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/documents`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(formData)
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.detail || 'Failed to create document');
      }

      const newDoc = await res.json();
      
      if (selectedFile) {
        const formDataFile = new FormData();
        formDataFile.append('file', selectedFile);
        
        await fetch(`${API_URL}/api/documents/${newDoc.id}/files`, {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${token}` },
          body: formDataFile
        });
      }

      setShowForm(false);
      fetchDocuments();
      setFormData({
        hospital: '',
        location: '',
        doctor_name: '',
        department: '',
        description: '',
        checkup_date: ''
      });
      setSelectedFile(null);
      if (fileInputRef.current) fileInputRef.current.value = '';
    } catch (err: any) {
      setError(err.message);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this document?')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/documents/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        setDocuments(documents.filter(d => d.id !== id));
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
          <h1 className="text-3xl font-bold text-text-main">Medical Records</h1>
        </div>

        <div className="mb-6">
          <Button onClick={() => setShowForm(!showForm)}>
            {showForm ? 'Cancel' : '+ Add Document'}
          </Button>
        </div>

        {error && !showForm && (
          <div className="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-2.5 text-sm text-red-800">
            {error}
          </div>
        )}

        {showForm && (
          <Card className="p-6 mb-8">
            <form onSubmit={handleSubmit} className="space-y-4">
              <Input
                label="Hospital Name"
                name="hospital"
                value={formData.hospital}
                onChange={(e) => setFormData({ ...formData, hospital: e.target.value })}
                placeholder="Enter hospital name"
                required
              />
              <Input
                label="Location"
                name="location"
                value={formData.location}
                onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                placeholder="City or address"
              />
              <Input
                label="Doctor Name"
                name="doctor_name"
                value={formData.doctor_name}
                onChange={(e) => setFormData({ ...formData, doctor_name: e.target.value })}
                placeholder="Doctor's name"
              />
              <Input
                label="Department"
                name="department"
                value={formData.department}
                onChange={(e) => setFormData({ ...formData, department: e.target.value })}
                placeholder="Department"
              />
              <Input
                label="Checkup Date"
                name="checkup_date"
                type="date"
                value={formData.checkup_date}
                onChange={(e) => setFormData({ ...formData, checkup_date: e.target.value })}
                required
              />
              
              <div className="flex flex-col gap-1.5 w-full">
                <label className="text-sm font-medium text-gray-700">Upload Photo (Optional)</label>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*,.pdf"
                  onChange={handleFileSelect}
                  className="flex h-10 w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-primary file:text-white hover:file:bg-blue-700"
                />
                {selectedFile && (
                  <p className="text-sm text-subtext">Selected: {selectedFile.name}</p>
                )}
              </div>

              <div className="flex flex-col gap-1.5 w-full">
                <label className="text-sm font-medium text-gray-700">Description</label>
                <textarea
                  name="description"
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="Add any notes..."
                  className="flex w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
                  rows={3}
                />
              </div>
              {error && <p className="text-red-500 text-sm">{error}</p>}
              <Button type="submit" disabled={uploading}>
                {uploading ? 'Saving...' : 'Save Document'}
              </Button>
            </form>
          </Card>
        )}

        {documents.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext mb-4">No medical records yet</p>
            <Button onClick={() => setShowForm(true)}>Add Your First Document</Button>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {documents.map((doc) => (
              <Card key={doc.id} className="p-6">
                <div className="flex justify-between items-start mb-2">
                  <h3 className="text-lg font-semibold text-text-main">{doc.hospital}</h3>
                  <button
                    onClick={() => toggleDocExpand(doc.id)}
                    className="text-primary text-sm hover:underline"
                  >
                    {expandedDoc === doc.id ? 'Hide Files' : 'Show Files'}
                  </button>
                </div>
                {doc.doctor_name && (
                  <p className="text-subtext text-sm mb-1">Dr. {doc.doctor_name}</p>
                )}
                {doc.department && (
                  <p className="text-subtext text-sm mb-1">{doc.department}</p>
                )}
                {doc.location && (
                  <p className="text-subtext text-sm mb-1">{doc.location}</p>
                )}
                {doc.checkup_date && (
                  <p className="text-subtext text-sm mb-2">
                    Date: {formatPlainDate(doc.checkup_date)}
                  </p>
                )}
                {doc.description && (
                  <p className="text-subtext text-sm mb-4">{doc.description}</p>
                )}
                
                {expandedDoc === doc.id && docFiles[doc.id] && docFiles[doc.id].length > 0 && (
                  <div className="mt-4 pt-4 border-t border-gray-100">
                    <p className="text-sm font-medium text-text-main mb-2">Uploaded Files:</p>
                    <div className="space-y-2">
                      {docFiles[doc.id].map((file) => (
                        <div key={file.id} className="flex items-center justify-between text-sm">
                          <span className="text-subtext truncate max-w-[150px]">{file.name}</span>
                          <button
                            onClick={() => handleViewFile(doc.id, file.id, file.name)}
                            className="text-primary hover:underline"
                          >
                            View
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
                
                <div className="flex gap-2 mt-4">
                  <button
                    onClick={() => handleDelete(doc.id)}
                    className="text-red-500 text-sm hover:underline"
                  >
                    Delete
                  </button>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>

      {viewingFile && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-auto">
            <div className="p-4 border-b flex justify-between items-center">
              <h3 className="font-medium">{viewingFile.name}</h3>
              <button onClick={closeViewer} className="text-gray-500 hover:text-gray-700">
                ✕
              </button>
            </div>
            <div className="p-4">
              {viewingFile.name.toLowerCase().endsWith('.pdf') ? (
                <iframe
                  src={viewingFile.url}
                  className="w-full h-[70vh]"
                  title={viewingFile.name}
                />
              ) : (
                <img
                  src={viewingFile.url}
                  alt={viewingFile.name}
                  className="max-w-full h-auto"
                />
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}