'use client';

import { useCallback, useEffect, useState, useRef } from 'react';
import { apiFetch, API_URL } from '@/lib/api';
import { useRouter } from 'next/navigation';
import { FolderOpen, Plus, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/ui/empty-state';
import { Dialog } from '@/components/ui/dialog';
import { LoadMore } from '@/components/load-more';
import { formatPlainDate } from '@/lib/datetime';



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

const INPUT_CLASS = "flex w-full h-11 rounded-sm border border-outline-strong bg-surface-card px-3.5 text-base text-on-surface placeholder:text-on-surface-variant/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring transition-colors";

export default function Documents() {
  const router = useRouter();
  const [documents, setDocuments] = useState<Document[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [offset, setOffset] = useState(0);
  const [total, setTotal] = useState(0);
  const PAGE_SIZE = 20;
  const [showForm, setShowForm] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
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

  const fetchDocuments = useCallback(async (fetchOffset = 0): Promise<{ documents: Document[]; total: number }> => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return { documents: [], total: 0 };
    }

    try {
      const res = await apiFetch(`${API_URL}/api/documents?offset=${fetchOffset}&limit=${PAGE_SIZE}`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json'
        }
      });

      if (res.ok) {
        const data = await res.json();
        return { documents: data.documents || [], total: data.total || 0 };
      }
    } catch (err) {
      console.error('Fetch error:', err);
    }
    return { documents: [], total: 0 };
  }, [router]);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const result = await fetchDocuments(0);
        if (!cancelled) {
          setDocuments(result.documents);
          setTotal(result.total);
          setOffset(result.documents.length);
        }
      } catch (err) { console.error(err); }
      if (!cancelled) setLoading(false);
    })();
    return () => { cancelled = true; };
  }, [router, fetchDocuments]);

  const fetchDocumentFiles = async (docId: string) => {
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/documents/${docId}/files`, {
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
      const res = await apiFetch(`${API_URL}/api/documents`, {
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

        await apiFetch(`${API_URL}/api/documents/${newDoc.id}/files`, {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${token}` },
          body: formDataFile
        });
      }

      setShowForm(false);
      const result = await fetchDocuments(0);
      setDocuments(result.documents);
      setTotal(result.total);
      setOffset(result.documents.length);
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
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to create document');
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this document?')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/documents/${id}`, {
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

  const handleLoadMore = async () => {
    setLoadingMore(true);
    try {
      const result = await fetchDocuments(offset);
      setDocuments((prev) => [...prev, ...result.documents]);
      setOffset((prev) => prev + result.documents.length);
      setTotal(result.total);
    } catch (err) {
      console.error(err);
    } finally {
      setLoadingMore(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-surface">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Skeleton className="h-8 w-48 mb-8" />
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[1, 2, 3].map((i) => <Skeleton key={i} className="h-44" />)}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-surface">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-display font-bold text-on-surface">Medical Records</h1>
        </div>

        <div className="mb-6">
          <Button onClick={() => setShowForm(!showForm)}>
            {showForm ? 'Cancel' : (
              <>
                <Plus className="w-4 h-4" /> Add Document
              </>
            )}
          </Button>
        </div>

        {error && !showForm && (
          <div className="mb-6 rounded-md border border-alert/40 bg-alert-container px-4 py-2.5 text-sm text-alert">
            {error}
          </div>
        )}

        {showForm && (
          <Card className="p-lg mb-8">
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
              </div>

              <div className="flex flex-col gap-1.5 w-full">
                <label className="text-sm font-semibold text-on-surface">Upload Photo (Optional)</label>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*,.pdf"
                  onChange={handleFileSelect}
                  className={`${INPUT_CLASS} file:mr-4 file:border-0 file:rounded-sm file:bg-primary file:px-4 file:py-2 file:text-sm file:font-medium file:text-on-primary hover:file:bg-primary-pressed`}
                />
                {selectedFile && (
                  <p className="text-sm text-on-surface-variant">Selected: {selectedFile.name}</p>
                )}
              </div>

              <div className="flex flex-col gap-1.5 w-full">
                <label className="text-sm font-semibold text-on-surface">Description</label>
                <textarea
                  name="description"
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="Add any notes..."
                  className={`${INPUT_CLASS} min-h-[72px] resize-y py-2.5`}
                  rows={3}
                />
              </div>
              {error && <p className="text-alert text-sm" role="alert">{error}</p>}
              <div className="flex gap-2">
                <Button type="submit">
                  Save Document
                </Button>
                <Button type="button" variant="ghost" onClick={() => setShowForm(false)}>Cancel</Button>
              </div>
            </form>
          </Card>
        )}

        {documents.length === 0 ? (
          <Card className="p-lg">
            <EmptyState
              icon={FolderOpen}
              title="No medical records yet"
              description="Add a record of a hospital visit and attach the photo of your papers to it."
              action={<Button onClick={() => setShowForm(true)}>Add Your First Document</Button>}
            />
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {documents.map((doc) => (
              <Card key={doc.id} className="p-lg">
                <div className="flex justify-between items-start mb-2">
                  <h3 className="text-lg font-display font-semibold text-on-surface">{doc.hospital}</h3>
                  <button
                    onClick={() => toggleDocExpand(doc.id)}
                    className="text-primary text-sm hover:underline"
                  >
                    {expandedDoc === doc.id ? 'Hide Files' : 'Show Files'}
                  </button>
                </div>
                {doc.doctor_name && (
                  <p className="text-on-surface-variant text-sm mb-1">Dr. {doc.doctor_name}</p>
                )}
                {doc.department && (
                  <p className="text-on-surface-variant text-sm mb-1">{doc.department}</p>
                )}
                {doc.location && (
                  <p className="text-on-surface-variant text-sm mb-1">{doc.location}</p>
                )}
                {doc.checkup_date && (
                  <p className="text-on-surface-variant text-sm mb-2">
                    Date: {formatPlainDate(doc.checkup_date)}
                  </p>
                )}
                {doc.description && (
                  <p className="text-on-surface-variant text-sm mb-4">{doc.description}</p>
                )}

                {expandedDoc === doc.id && docFiles[doc.id] && docFiles[doc.id].length > 0 && (
                  <div className="mt-4 pt-4 border-t border-outline">
                    <p className="text-sm font-medium text-on-surface mb-2">Uploaded Files:</p>
                    <div className="space-y-2">
                      {docFiles[doc.id].map((file) => (
                        <div key={file.id} className="flex items-center justify-between text-sm">
                          <span className="text-on-surface-variant truncate max-w-[150px]">{file.name}</span>
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
                    className="text-alert text-sm hover:underline"
                  >
                    Delete
                  </button>
                </div>
              </Card>
            ))}
          </div>
        )}

        {documents.length > 0 && (
          <LoadMore
            offset={offset}
            total={total}
            limit={PAGE_SIZE}
            loading={loadingMore}
            onLoadMore={handleLoadMore}
          />
        )}
      </div>

      <Dialog open={viewingFile !== null} onClose={closeViewer} className="max-w-4xl">
        {viewingFile && (
          <>
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-display font-semibold text-on-surface">{viewingFile.name}</h3>
              <button onClick={closeViewer} className="text-on-surface-variant hover:text-on-surface transition-colors" aria-label="Close">
                <X className="w-5 h-5" />
              </button>
            </div>
            {viewingFile.name.toLowerCase().endsWith('.pdf') ? (
              <iframe src={viewingFile.url} className="w-full h-[70vh] rounded-sm border border-outline" title={viewingFile.name} />
            ) : (
              /* eslint-disable-next-line @next/next/no-img-element */
              <img src={viewingFile.url} alt={viewingFile.name} className="max-w-full h-auto rounded-sm border border-outline" />
            )}
          </>
        )}
      </Dialog>
    </div>
  );
}