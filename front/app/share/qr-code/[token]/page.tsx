'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Card } from '@/components/card';
import { Button } from '@/components/button';
import ClaimShareButton from '@/components/ClaimShareButton';
import { formatPlainDate, formatServerDateTime } from '@/lib/datetime';
import { API_URL } from '@/lib/api';



interface Report {
  id: string;
  report_type: string;
  file_name: string;
  file_content: string;
  notes?: string;
  doctor_name?: string;
  hospital?: string;
  created_at?: string;
}

interface LabFinding {
  name: string;
  value: number;
  unit: string;
  status: 'HIGH' | 'LOW' | 'NORMAL';
  reference_range: string;
  category: string;
}

interface LabAnalysis {
  overall: string;
  abnormal_count: number;
  findings: LabFinding[];
}

const STATUS_STYLES: Record<string, string> = {
  HIGH: 'bg-red-100 text-red-800',
  LOW: 'bg-amber-100 text-amber-800',
  NORMAL: 'bg-green-100 text-green-800',
};

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
  user_id?: string;
  user_blood_type?: string;
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
  // Which panel (if any) is open per report, plus caches for fetched data.
  const [panels, setPanels] = useState<Record<string, 'lab' | null>>({});
  const [labCache, setLabCache] = useState<Record<string, LabAnalysis | 'loading' | 'error'>>({});
  // PIN gate: whole-record shares are PIN-protected, so the reader asks for
  // the 6-digit code before the first request goes out.
  const [needsPin, setNeedsPin] = useState(false);
  const [pin, setPin] = useState('');
  const [pinError, setPinError] = useState('');

  useEffect(() => {
    if (token) {
      fetchReports();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  const fetchReports = async (enteredPin?: string) => {
    try {
      const query = enteredPin ? `?pin=${encodeURIComponent(enteredPin)}` : '';
      const res = await fetch(`${API_URL}/api/share/qr-code/${token}${query}`);
      if (res.status === 401) {
        const errData = await res.json().catch(() => ({ detail: 'PIN required' }));
        setPinError(errData.detail || 'This health record is PIN-protected.');
        setNeedsPin(true);
        setLoading(false);
        return;
      }
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

  const submitPin = () => {
    setPinError('');
    setLoading(true);
    setNeedsPin(false);
    fetchReports(pin.trim());
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

  const showLab = async (id: string) => {
    setPanels(p => ({ ...p, [id]: p[id] === 'lab' ? null : 'lab' }));
    if (labCache[id]) return;
    setLabCache(c => ({ ...c, [id]: 'loading' }));
    try {
      const res = await fetch(`${API_URL}/api/share/${token}/lab-analysis?report_id=${id}`);
      const result: LabAnalysis | 'error' = res.ok ? (await res.json()) as LabAnalysis : 'error';
      setLabCache(c => ({ ...c, [id]: result }));
    } catch {
      setLabCache(c => ({ ...c, [id]: 'error' }));
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-subtext">Loading...</p>
      </div>
    );
  }

  if (needsPin) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <Card className="p-8 max-w-md w-full">
          <h2 className="text-xl font-bold text-text-main mb-2">PIN required</h2>
          <p className="text-subtext mb-4">
            This health record is PIN-protected. Ask the owner for the 6-digit
            PIN that came with the QR code.
          </p>
          <input
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            maxLength={6}
            value={pin}
            onChange={(e) => setPin(e.target.value.replace(/\D/g, ''))}
            placeholder="6-digit PIN"
            className="w-full h-11 rounded-lg border border-gray-300 px-3.5 text-base focus:outline-none focus:ring-2 focus:ring-blue-500 mb-3"
          />
          {pinError && (
            <p className="text-sm text-red-600 mb-3">{pinError}</p>
          )}
          <Button onClick={submitPin} disabled={pin.length !== 6} className="w-full">
            View health record
          </Button>
        </Card>
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
        <ClaimShareButton token={token} />

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
                  <p className="text-subtext text-xs mb-0.5">Started: {formatPlainDate(med.start_date)}</p>
                  {med.end_date && <p className="text-subtext text-xs mb-0.5">Ends: {formatPlainDate(med.end_date)}</p>}
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
                        Uploaded: {formatServerDateTime(report.created_at)}
                      </p>
                    )}
                  </div>
                </div>

                <div className="flex gap-2 flex-wrap mb-3">
                  <button
                    onClick={() => handleViewReport(report)}
                    className="px-3 py-1.5 rounded-lg bg-primary/10 text-primary font-medium text-sm hover:bg-primary/20 transition-colors"
                  >
                    View Original
                  </button>
                  <button
                    onClick={() => showLab(report.id)}
                    className="px-3 py-1.5 rounded-lg bg-teal-50 text-teal-700 font-medium text-sm hover:bg-teal-100 transition-colors"
                  >
                    {panels[report.id] === 'lab' ? 'Hide Lab Values' : 'Lab Values'}
                  </button>
                </div>

                {panels[report.id] === 'lab' && (
                  <div className="border border-gray-100 rounded-lg p-4">
                    {labCache[report.id] === 'loading' || labCache[report.id] === undefined ? (
                      <p className="text-subtext text-sm">Analyzing lab values…</p>
                    ) : labCache[report.id] === 'error' ? (
                      <p className="text-subtext text-sm">Could not analyze lab values for this report.</p>
                    ) : (() => {
                      const lab = labCache[report.id] as LabAnalysis;
                      if (lab.findings.length === 0) {
                        return <p className="text-subtext text-sm">No recognizable lab values found in this report.</p>;
                      }
                      return (
                        <>
                          <div className="mb-3 flex items-center gap-2">
                            <span className={`text-xs font-semibold px-2 py-1 rounded ${lab.overall === 'ABNORMAL' ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'}`}>
                              {lab.overall}
                            </span>
                            <span className="text-sm text-subtext">{lab.abnormal_count} value(s) outside normal range</span>
                          </div>
                          <div className="space-y-2">
                            {lab.findings.map((f, i) => (
                              <div key={i} className="flex items-center justify-between border border-gray-100 rounded-lg px-3 py-2">
                                <div className="min-w-0">
                                  <p className="font-medium text-text-main text-sm truncate">{f.name}</p>
                                  <p className="text-[11px] text-subtext">{f.category} · Normal {f.reference_range} {f.unit}</p>
                                </div>
                                <div className="flex items-center gap-2 shrink-0">
                                  <span className="font-semibold text-text-main text-sm">{f.value} <span className="text-xs text-subtext">{f.unit}</span></span>
                                  <span className={`text-[10px] font-semibold px-1.5 py-0.5 rounded ${STATUS_STYLES[f.status]}`}>{f.status}</span>
                                </div>
                              </div>
                            ))}
                          </div>
                        </>
                      );
                    })()}
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
