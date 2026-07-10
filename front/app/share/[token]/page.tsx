'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Card } from '@/components/card';
import { Button } from '@/components/button';
import { DigitizedReport } from '@/components/DigitizedReport';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface SharedReport {
  id: string;
  report_type: string;
  file_name: string;
  file_content: string;
  notes?: string;
  ai_report_text?: string;
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

interface EmergencyContact {
  name: string;
  relationship: string;
  phone: string;
}

interface EmergencyInfo {
  blood_type: string | null;
  allergies: string | null;
  medical_conditions: string | null;
  emergency_contacts: EmergencyContact[];
}

interface SharedReportResponse {
  report: SharedReport;
  emergency: EmergencyInfo;
  user_name?: string;
  user_id?: string;
  user_blood_type?: string;
}

export default function ViewSharedReport() {
  const params = useParams();
  const router = useRouter();
  const token = params.token as string;
  
  const [responseData, setResponseData] = useState<SharedReportResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [fileUrl, setFileUrl] = useState<string | null>(null);
  const [digitizedReport, setDigitizedReport] = useState<SharedReport | null>(null);
  const [labAnalysis, setLabAnalysis] = useState<LabAnalysis | null>(null);
  const [labLoading, setLabLoading] = useState(true);
  const [explanation, setExplanation] = useState<string | null>(null);
  const [explainLoading, setExplainLoading] = useState(false);

  const report = responseData?.report ?? null;
  const emergency = responseData?.emergency;

  useEffect(() => {
    if (token) {
      fetchReport();
      fetchLabAnalysis();
    }
  }, [token]);

  const fetchLabAnalysis = async () => {
    setLabLoading(true);
    try {
      const res = await fetch(`${API_URL}/api/share/${token}/lab-analysis`);
      if (res.ok) {
        setLabAnalysis(await res.json());
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLabLoading(false);
    }
  };

  const handleExplain = async () => {
    setExplainLoading(true);
    try {
      const res = await fetch(`${API_URL}/api/share/${token}/explain`);
      const data = await res.json();
      setExplanation(res.ok ? data.explanation : `Could not generate explanation: ${data.detail || 'unknown error'}`);
    } catch {
      setExplanation('Network error. Please try again.');
    } finally {
      setExplainLoading(false);
    }
  };

  const fetchReport = async () => {
    try {
      const res = await fetch(`${API_URL}/api/share/${token}`);
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.detail || 'Link not found or expired');
      }
      const data = await res.json();
      setResponseData(data);
      
      if (data.report?.file_content) {
        const byteCharacters = atob(data.report.file_content);
        const byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i++) {
          byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        const byteArray = new Uint8Array(byteNumbers);
        const blob = new Blob([byteArray], { type: 'application/pdf' });
        const url = URL.createObjectURL(blob);
        setFileUrl(url);
      }
    } catch (err: any) {
      setError(err.message || 'Failed to load report');
    } finally {
      setLoading(false);
    }
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
          <Button onClick={() => router.push('/auth/login')}>Login to MediStore</Button>
        </div>
        
        <div className="mb-6 flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-main mb-1">
              {report?.report_type.replace('_', ' ')}
            </h1>
            {report?.created_at && (
              <p className="text-subtext text-sm">
                Uploaded: {new Date(report.created_at).toLocaleString()}
              </p>
            )}
          </div>
          <button
            onClick={() => setDigitizedReport(report)}
            className="px-3 py-1.5 rounded-lg bg-emerald-50 text-emerald-700 font-medium text-sm hover:bg-emerald-100 transition-colors shrink-0"
          >
            Digital Report
          </button>
        </div>

        {emergency && (emergency.blood_type || emergency.allergies || emergency.medical_conditions || emergency.emergency_contacts.length > 0) && (
          <Card className="p-4 sm:p-6 mb-6 border-2 border-red-200 bg-red-50">
            <div className="flex items-center gap-2 mb-4">
              <svg className="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4.5c-.77-.833-1.964-.833-2.732 0L4.068 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
              <h2 className="text-lg font-semibold text-red-800">Emergency Medical ID</h2>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-4">
              {emergency.blood_type && (
                <div className="bg-white rounded-lg p-3 border border-red-200">
                  <p className="text-xs text-red-600 font-medium uppercase tracking-wider">Blood Type</p>
                  <p className="text-xl font-bold text-red-800 mt-1">{emergency.blood_type}</p>
                </div>
              )}
              {emergency.allergies && (
                <div className="bg-white rounded-lg p-3 border border-red-200">
                  <p className="text-xs text-red-600 font-medium uppercase tracking-wider">Allergies</p>
                  <p className="text-sm font-medium text-gray-800 mt-1">{emergency.allergies}</p>
                </div>
              )}
              {emergency.medical_conditions && (
                <div className="bg-white rounded-lg p-3 border border-red-200">
                  <p className="text-xs text-red-600 font-medium uppercase tracking-wider">Medical Conditions</p>
                  <p className="text-sm font-medium text-gray-800 mt-1">{emergency.medical_conditions}</p>
                </div>
              )}
            </div>
            {emergency.emergency_contacts.length > 0 && (
              <div>
                <p className="text-xs font-medium text-red-700 mb-2 uppercase tracking-wider">Emergency Contacts</p>
                <div className="space-y-2">
                  {emergency.emergency_contacts.map((c, i) => (
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

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
          <Card className="p-6">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-6 h-6 bg-blue-100 rounded flex items-center justify-center">
                <span className="text-blue-700 text-xs font-bold">O</span>
              </div>
              <h2 className="text-lg font-semibold text-text-main">Original Document</h2>
            </div>
            {fileUrl ? (
              report?.file_name?.toLowerCase().endsWith('.pdf') ? (
                <iframe
                  src={fileUrl}
                  className="w-full h-[50vh] border rounded-lg"
                  title={report?.file_name}
                />
              ) : (
                <img
                  src={fileUrl}
                  alt={report?.file_name}
                  className="max-w-full h-auto border rounded-lg"
                />
              )
            ) : (
              <p className="text-subtext text-sm">No file preview available</p>
            )}
            <p className="text-subtext text-xs mt-2">{report?.file_name}</p>
          </Card>

          <Card className="p-6">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-6 h-6 bg-teal-100 rounded flex items-center justify-center">
                <span className="text-teal-700 text-xs font-bold">L</span>
              </div>
              <h2 className="text-lg font-semibold text-text-main">Lab Findings</h2>
            </div>
            {labLoading ? (
              <p className="text-subtext text-sm py-4">Analyzing lab values…</p>
            ) : !labAnalysis || labAnalysis.findings.length === 0 ? (
              <p className="text-subtext text-sm">No recognizable lab values found in this report.</p>
            ) : (
              <>
                <div className="mb-3 flex items-center gap-2">
                  <span className={`text-xs font-semibold px-2 py-1 rounded ${labAnalysis.overall === 'ABNORMAL' ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'}`}>
                    {labAnalysis.overall}
                  </span>
                  <span className="text-sm text-subtext">{labAnalysis.abnormal_count} value(s) outside normal range</span>
                </div>
                <div className="space-y-2 max-h-[52vh] overflow-y-auto">
                  {labAnalysis.findings.map((f, i) => (
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
                <p className="text-[11px] text-subtext mt-3">Flagged against typical adult reference ranges (educational).</p>
              </>
            )}
          </Card>
        </div>

        <Card className="p-6 mb-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-2">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 bg-sky-100 rounded-lg flex items-center justify-center">
                <span className="text-sky-700 text-xs font-bold">AI</span>
              </div>
              <div>
                <h2 className="text-lg font-semibold text-text-main">In Plain Language</h2>
                <p className="text-xs text-subtext">Simplified by MediStore AI · not medical advice</p>
              </div>
            </div>
            {!explanation && (
              <Button onClick={handleExplain} disabled={explainLoading} className="shrink-0">
                {explainLoading ? 'Explaining…' : 'Explain Simply'}
              </Button>
            )}
          </div>
          {explainLoading ? (
            <p className="text-subtext text-sm py-4">AI is explaining this report…</p>
          ) : explanation ? (
            <p className="text-sm text-text-main whitespace-pre-wrap leading-relaxed mt-2">{explanation}</p>
          ) : (
            <p className="text-subtext text-sm mt-2">Get a patient-friendly, jargon-free summary of this report.</p>
          )}
        </Card>

        {report?.notes && (
          <Card className="p-4 mb-6">
            <p className="text-sm text-subtext">Patient Notes</p>
            <p className="text-text-main italic">{report.notes}</p>
          </Card>
        )}
      </div>

      {digitizedReport && (
        <DigitizedReport
          report={digitizedReport}
          user={{
            name: responseData?.user_name || 'Patient',
            id: responseData?.user_id || '',
            email: '',
            blood_type: responseData?.user_blood_type || undefined,
          }}
          onClose={() => setDigitizedReport(null)}
        />
      )}
    </div>
  );
}
