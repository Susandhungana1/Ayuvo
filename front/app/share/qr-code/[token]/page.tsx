'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Card } from '@/components/card';
import { Button } from '@/components/button';
import { FormalReportView } from '@/components/FormalReportView';

const API_URL = 'http://127.0.0.1:3001';

interface Report {
  id: string;
  report_type: string;
  file_name: string;
  file_content: string;
  notes?: string;
  ai_report_text?: string;
  created_at?: string;
}

interface MedicineItem {
  id: string;
  name: string;
  dosage: string;
  frequency: string;
  start_date: string;
  end_date?: string;
  notes?: string;
}

interface EmergencyContactItem {
  name: string;
  relationship: string;
  phone: string;
}

interface EmergencyInfo {
  blood_type: string | null;
  allergies: string | null;
  medical_conditions: string | null;
  emergency_contacts: EmergencyContactItem[];
}

interface AllReportsData {
  user_name: string;
  emergency: EmergencyInfo;
  reports: Report[];
  medicines: MedicineItem[];
}

export default function ViewAllSharedReports() {
  const params = useParams();
  const router = useRouter();
  const token = params.token as string;
  
  const [data, setData] = useState<AllReportsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [viewingReport, setViewingReport] = useState<{url: string; name: string} | null>(null);
  const [expandedAiReports, setExpandedAiReports] = useState<Set<string>>(new Set());

  useEffect(() => {
    if (token) {
      fetchReports();
    }
  }, [token]);

  const fetchReports = async () => {
    try {
      const res = await fetch(`${API_URL}/api/share/qr-code/${token}`);
      if (!res.ok) {
        const errData = await res.json();
        throw new Error(errData.detail || 'Link not found or expired');
      }
      const result = await res.json();
      setData(result);
    } catch (err: any) {
      setError(err.message || 'Failed to load reports');
    } finally {
      setLoading(false);
    }
  };

  const handleViewReport = (report: Report) => {
    if (report.file_content) {
      const byteCharacters = atob(report.file_content);
      const byteNumbers = new Array(byteCharacters.length);
      for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
      }
      const byteArray = new Uint8Array(byteNumbers);
      const mimeType = report.file_name?.toLowerCase().endsWith('.pdf') 
        ? 'application/pdf' 
        : 'image/png';
      const blob = new Blob([byteArray], { type: mimeType });
      const url = URL.createObjectURL(blob);
      setViewingReport({ url, name: report.file_name });
    }
  };

  const toggleAiReport = (id: string) => {
    const next = new Set(expandedAiReports);
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }
    setExpandedAiReports(next);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-subtext">Loading...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <Card className="p-8 text-center max-w-md">
          <h2 className="text-xl font-bold text-red-600 mb-2">Error</h2>
          <p className="text-subtext mb-4">{error}</p>
          <Button onClick={() => router.push('/')}>Go to Home</Button>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-6">
          <Button onClick={() => router.push('/auth/login')}>Login to HealthTracker</Button>
        </div>
        
        <h1 className="text-2xl font-bold text-text-main mb-2">
          Medical Information from {data?.user_name}
        </h1>
        <p className="text-subtext mb-6">{data?.reports.length} report(s) &middot; {data?.medicines.length} medicine(s)</p>

        {data?.emergency && (data.emergency.blood_type || data.emergency.allergies || data.emergency.medical_conditions || data.emergency.emergency_contacts.length > 0) && (
          <Card className="p-4 sm:p-6 mb-8 border-2 border-red-200 bg-red-50">
            <div className="flex items-center gap-2 mb-4">
              <svg className="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4.5c-.77-.833-1.964-.833-2.732 0L4.068 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
              <h2 className="text-lg font-semibold text-red-800">Emergency Medical ID</h2>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-4">
              {data.emergency.blood_type && (
                <div className="bg-white rounded-lg p-3 border border-red-200">
                  <p className="text-xs text-red-600 font-medium uppercase tracking-wider">Blood Type</p>
                  <p className="text-xl font-bold text-red-800 mt-1">{data.emergency.blood_type}</p>
                </div>
              )}
              {data.emergency.allergies && (
                <div className="bg-white rounded-lg p-3 border border-red-200">
                  <p className="text-xs text-red-600 font-medium uppercase tracking-wider">Allergies</p>
                  <p className="text-sm font-medium text-gray-800 mt-1">{data.emergency.allergies}</p>
                </div>
              )}
              {data.emergency.medical_conditions && (
                <div className="bg-white rounded-lg p-3 border border-red-200">
                  <p className="text-xs text-red-600 font-medium uppercase tracking-wider">Medical Conditions</p>
                  <p className="text-sm font-medium text-gray-800 mt-1">{data.emergency.medical_conditions}</p>
                </div>
              )}
            </div>
            {data.emergency.emergency_contacts.length > 0 && (
              <div>
                <p className="text-xs font-medium text-red-700 mb-2 uppercase tracking-wider">Emergency Contacts</p>
                <div className="space-y-2">
                  {data.emergency.emergency_contacts.map((c, i) => (
                    <div key={i} className="bg-white rounded-lg p-3 border border-red-200 flex justify-between items-center">
                      <span className="font-medium text-gray-800 text-sm">{c.name} ({c.relationship})</span>
                      <span className="text-sm text-red-700 font-medium">{c.phone}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </Card>
        )}

        {data && data.medicines.length > 0 && (
          <div className="mb-8">
            <h2 className="text-lg font-semibold text-text-main mb-3 flex items-center gap-2">
              <svg className="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9h3m7 0h3M5 15h3m7 0h3M2 7h20v10H2V7z" />
              </svg>
              Medicines
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {data.medicines.map((med) => (
                <Card key={med.id} className="p-4 border-l-4 border-l-green-400">
                  <h3 className="font-semibold text-text-main mb-1">{med.name}</h3>
                  <p className="text-subtext text-xs mb-0.5">Dosage: {med.dosage}</p>
                  <p className="text-subtext text-xs mb-0.5">Frequency: {med.frequency}</p>
                  <p className="text-subtext text-xs mb-0.5">Started: {new Date(med.start_date).toLocaleDateString()}</p>
                  {med.end_date && <p className="text-subtext text-xs mb-0.5">Ends: {new Date(med.end_date).toLocaleDateString()}</p>}
                  {med.notes && <p className="text-subtext text-xs mt-1 italic">{med.notes}</p>}
                </Card>
              ))}
            </div>
          </div>
        )}

        <h2 className="text-lg font-semibold text-text-main mb-3">Medical Reports</h2>
        
        {data?.reports.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext">No reports shared</p>
          </Card>
        ) : (
          <div className="space-y-6">
            {data?.reports.map((report, index) => (
              <Card key={report.id} className="p-5">
                <div className="flex items-start gap-3 mb-2">
                  <div className="w-7 h-7 bg-primary rounded-full flex items-center justify-center text-white text-xs font-bold shrink-0">
                    {index + 1}
                  </div>
                  <div className="flex-1 min-w-0">
                    <h3 className="font-semibold text-text-main">
                      {report.report_type.replace('_', ' ')}
                    </h3>
                    <p className="text-subtext text-xs">{report.file_name}</p>
                    {report.created_at && (
                      <p className="text-subtext text-xs">
                        Uploaded: {new Date(report.created_at).toLocaleString()}
                      </p>
                    )}
                  </div>
                </div>

                <div className="flex gap-2 mb-3">
                  <button
                    onClick={() => handleViewReport(report)}
                    className="text-primary text-sm hover:underline"
                  >
                    View Original
                  </button>
                  {report.ai_report_text && (
                    <button
                      onClick={() => toggleAiReport(report.id)}
                      className="text-purple-600 text-sm hover:underline"
                    >
                      {expandedAiReports.has(report.id) ? 'Hide AI Report' : 'AI Report'}
                    </button>
                  )}
                </div>

                {expandedAiReports.has(report.id) && report.ai_report_text && (
                  <div className="border rounded-lg overflow-hidden">
                    <FormalReportView content={report.ai_report_text} />
                  </div>
                )}
              </Card>
            ))}
          </div>
        )}
      </div>

      {viewingReport && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-auto">
            <div className="p-4 border-b flex justify-between items-center">
              <h3 className="font-medium">{viewingReport.name}</h3>
              <button onClick={() => setViewingReport(null)} className="text-gray-500 hover:text-gray-700">
                ✕
              </button>
            </div>
            <div className="p-4">
              {viewingReport.name.toLowerCase().endsWith('.pdf') ? (
                <iframe
                  src={viewingReport.url}
                  className="w-full h-[70vh]"
                  title={viewingReport.name}
                />
              ) : (
                <img
                  src={viewingReport.url}
                  alt={viewingReport.name}
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
