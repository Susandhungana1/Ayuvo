'use client';

import { useEffect, useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Input } from '@/components/input';
import { DigitizedReport } from '@/components/DigitizedReport';
import { generateReportPdf } from '@/lib/reportPdf';
import { cacheGet, cacheSet } from '@/lib/offlineCache';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface Report {
  id: string;
  report_type: string;
  report_date?: string;
  file_name: string;
  notes?: string;
  result_summary?: string;
  extracted_text?: string;
  ai_report_text?: string;
  document_id?: string;
  doctor_name?: string;
  hospital?: string;
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
  reportName: string;
  overall: string;
  abnormal_count: number;
  findings: LabFinding[];
}

interface TrendSeries {
  name: string;
  unit: string;
  reference_range: string;
  first_value: number;
  last_value: number;
  change: number;
  percent_change: number | null;
  direction: 'up' | 'down' | 'flat';
  latest_status: 'HIGH' | 'LOW' | 'NORMAL';
}

const STATUS_STYLES: Record<string, string> = {
  HIGH: 'bg-red-100 text-red-800',
  LOW: 'bg-amber-100 text-amber-800',
  NORMAL: 'bg-green-100 text-green-800',
};

export default function Reports() {
  const router = useRouter();
  const [reports, setReports] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);
  const [offlineCopy, setOfflineCopy] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [reportType, setReportType] = useState('');
  const [reportDate, setReportDate] = useState('');
  const [notes, setNotes] = useState('');
  const [hospitalName, setHospitalName] = useState('');
  const [verifiedBy, setVerifiedBy] = useState('');
  const [uploadedReport, setUploadedReport] = useState<Report | null>(null);
  const [viewingReport, setViewingReport] = useState<{url: string; name: string} | null>(null);
  const [digitizedReport, setDigitizedReport] = useState<Report | null>(null);
  const [labAnalysis, setLabAnalysis] = useState<LabAnalysis | null>(null);
  const [labLoading, setLabLoading] = useState(false);
  const [explain, setExplain] = useState<{ title: string; text: string } | null>(null);
  const [explainLoading, setExplainLoading] = useState(false);
  const [trends, setTrends] = useState<TrendSeries[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    fetchReports();
    fetchTrends();
  }, [router]);

  const fetchTrends = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/reports/trends`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setTrends(data.series || []);
      }
    } catch (err) { console.error(err); }
  };

  const handleLabAnalysis = async (report: Report) => {
    setLabLoading(true);
    setLabAnalysis({ reportName: report.report_type.replace('_', ' '), overall: '', abnormal_count: 0, findings: [] });
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/reports/${report.id}/lab-analysis`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setLabAnalysis({ reportName: report.report_type.replace('_', ' '), ...data });
      }
    } catch (err) { console.error(err); }
    finally { setLabLoading(false); }
  };

  const handleExplain = async (report: Report) => {
    setExplainLoading(true);
    setExplain({ title: report.report_type.replace('_', ' '), text: '' });
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/reports/${report.id}/explain`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await res.json();
      if (res.ok) {
        setExplain({ title: report.report_type.replace('_', ' '), text: data.explanation });
      } else {
        setExplain({ title: report.report_type.replace('_', ' '), text: `Could not generate explanation: ${data.detail || 'unknown error'}` });
      }
    } catch {
      setExplain({ title: report.report_type.replace('_', ' '), text: 'Network error. Please try again.' });
    } finally { setExplainLoading(false); }
  };

  const handleDownloadPdf = async (report: Report) => {
    // Try to enrich the PDF with parsed lab findings; fall back gracefully.
    let findings;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/reports/${report.id}/lab-analysis`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        findings = data.findings;
      }
    } catch { /* PDF still generates without findings */ }
    generateReportPdf(report, findings);
  };

  const fetchReports = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/reports`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        const list = data.reports || [];
        setReports(list);
        setOfflineCopy(false);
        cacheSet('reports', list); // keep a local copy for offline viewing
        return;
      }
      throw new Error('bad response');
    } catch (err) {
      // Network/backend down: fall back to the last cached copy if we have one.
      const cached = await cacheGet<Report[]>('reports');
      if (cached && cached.data.length) {
        setReports(cached.data);
        setOfflineCopy(true);
      } else {
        console.error(err);
      }
    } finally {
      setLoading(false);
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setSelectedFile(e.target.files[0]);
    }
  };

  const handleUpload = async () => {
    if (!selectedFile) return;
    setUploading(true);
    setUploadedReport(null);
    try {
      const formData = new FormData();
      formData.append('file', selectedFile);
      formData.append('report_type', reportType || 'OTHER');
      if (reportDate) formData.append('report_date', reportDate);
      if (notes) formData.append('notes', notes);
      if (hospitalName) formData.append('hospital', hospitalName);
      if (verifiedBy) formData.append('doctor_name', verifiedBy);
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/reports`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData
      });
      if (res.ok) {
        const data = await res.json();
        setUploadedReport(data);
        fetchReports();
        setSelectedFile(null);
        setNotes('');
        setHospitalName('');
        setVerifiedBy('');
        setReportType('');
        setReportDate('');
        if (fileInputRef.current) fileInputRef.current.value = '';
      } else {
        const err = await res.json();
        alert(err.detail || 'Failed to process file');
      }
    } catch (err: any) {
      alert(err.message || 'Failed to process file');
    } finally {
      setUploading(false);
    }
  };

  const handleViewReport = async (report: Report) => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/reports/${report.id}/file`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const blob = await res.blob();
        const url = URL.createObjectURL(blob);
        setViewingReport({ url, name: report.file_name });
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this report?')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/reports/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        setReports(reports.filter(r => r.id !== id));
      }
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-text-main">Medical Reports</h1>
        </div>

        <Card className="p-6 mb-8">
          <h2 className="text-xl font-semibold text-text-main mb-4">Upload Medical Report</h2>
          <p className="text-subtext text-sm mb-4">
            Upload a photo or file of your medical report. AI will read the text and generate a formal medical report.
          </p>
          <div className="space-y-4">
            <div className="flex flex-col gap-1.5 w-full">
              <label className="text-sm font-medium text-gray-700">Upload File (Photo/PDF)</label>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*,.pdf"
                onChange={handleFileSelect}
                className="flex h-10 w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-primary file:text-white hover:file:bg-blue-700"
              />
              {selectedFile && <p className="text-sm text-subtext">Selected: {selectedFile.name}</p>}
            </div>

            <div className="flex flex-col gap-1.5 w-full">
              <label className="text-sm font-medium text-gray-700">Report Type</label>
              <select
                value={reportType}
                onChange={(e) => setReportType(e.target.value)}
                className="flex h-10 w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
              >
                <option value="">Select type</option>
                <option value="BLOOD_TEST">Blood Test</option>
                <option value="URINE_TEST">Urine Test</option>
                <option value="XRAY">X-Ray</option>
                <option value="MRI">MRI</option>
                <option value="CT_SCAN">CT Scan</option>
                <option value="ULTRASOUND">Ultrasound</option>
                <option value="ECG">ECG</option>
                <option value="OTHER">Other</option>
              </select>
            </div>

            <Input
              label="Report Date"
              name="report_date"
              type="date"
              value={reportDate}
              onChange={(e) => setReportDate(e.target.value)}
            />

            <div className="flex flex-col gap-1.5 w-full">
              <label className="text-sm font-medium text-gray-700">Hospital Name</label>
              <input
                type="text"
                value={hospitalName}
                onChange={(e) => setHospitalName(e.target.value)}
                placeholder="e.g. Bir Hospital, Kathmandu"
                className="flex h-10 w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
              />
            </div>

            <div className="flex flex-col gap-1.5 w-full">
              <label className="text-sm font-medium text-gray-700">Verified By (Doctor)</label>
              <input
                type="text"
                value={verifiedBy}
                onChange={(e) => setVerifiedBy(e.target.value)}
                placeholder="e.g. Dr. Ram Sharma"
                className="flex h-10 w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
              />
            </div>

            <div className="flex flex-col gap-1.5 w-full">
              <label className="text-sm font-medium text-gray-700">Your Notes</label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Add any notes like: This is my annual checkup, I was feeling tired lately..."
                className="flex w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600"
                rows={3}
              />
            </div>

            <Button onClick={handleUpload} disabled={!selectedFile || uploading}>
              {uploading ? (
                <span className="flex items-center gap-2">
                  <svg className="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  AI is reading your report...
                </span>
              ) : 'Upload & Generate Report'}
            </Button>

            {uploadedReport && (
              <div className="mt-4 flex items-start gap-2 rounded-lg bg-green-50 border border-green-200 px-4 py-3">
                <svg className="w-5 h-5 text-green-600 shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <p className="text-sm text-green-800">
                  Report uploaded. Use <span className="font-medium">Lab Values</span> and <span className="font-medium">Explain Simply</span> on the report below to review it.
                </p>
              </div>
            )}
          </div>
        </Card>

        {loading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[1, 2, 3].map((i) => (
              <div key={i} className="bg-white rounded-xl border border-gray-100 p-6 animate-pulse">
                <div className="h-5 bg-gray-200 rounded w-2/3 mb-3" />
                <div className="h-4 bg-gray-200 rounded w-1/2 mb-2" />
                <div className="h-4 bg-gray-200 rounded w-3/4 mb-4" />
                <div className="flex gap-2">
                  <div className="h-8 bg-gray-200 rounded-lg w-16" />
                  <div className="h-8 bg-gray-200 rounded-lg w-20" />
                  <div className="h-8 bg-gray-200 rounded-lg w-16" />
                </div>
              </div>
            ))}
          </div>
        ) : reports.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext mb-4">No medical reports yet</p>
            <p className="text-subtext text-sm">Upload your first report above</p>
          </Card>
        ) : (
          <div>
            {trends.length > 0 && (
              <Card className="p-6 mb-8">
                <h2 className="text-xl font-semibold text-text-main mb-1">Health Trends</h2>
                <p className="text-subtext text-sm mb-4">How your lab values have changed across reports over time.</p>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  {trends.map((t) => {
                    const arrow = t.direction === 'up' ? '▲' : t.direction === 'down' ? '▼' : '—';
                    return (
                      <div key={t.name} className="border border-gray-200 rounded-lg p-4">
                        <div className="flex justify-between items-start mb-1">
                          <span className="font-medium text-text-main text-sm">{t.name}</span>
                          <span className={`text-[10px] font-semibold px-1.5 py-0.5 rounded ${STATUS_STYLES[t.latest_status]}`}>{t.latest_status}</span>
                        </div>
                        <div className="flex items-baseline gap-2">
                          <span className="text-lg font-bold text-text-main">{t.last_value}</span>
                          <span className="text-xs text-subtext">{t.unit}</span>
                        </div>
                        <p className="text-xs text-subtext mt-1">
                          {t.first_value} → {t.last_value}{' '}
                          <span className={t.direction === 'up' ? 'text-red-600' : t.direction === 'down' ? 'text-green-600' : 'text-gray-500'}>
                            {arrow} {t.percent_change !== null ? `${Math.abs(t.percent_change)}%` : ''}
                          </span>
                        </p>
                        <p className="text-[11px] text-subtext mt-1">Normal: {t.reference_range} {t.unit}</p>
                      </div>
                    );
                  })}
                </div>
              </Card>
            )}
            <h2 className="text-xl font-semibold text-text-main mb-4">Your Reports</h2>
            {offlineCopy && (
              <div className="mb-4 flex items-center gap-2 rounded-lg bg-amber-50 border border-amber-200 px-4 py-2.5">
                <svg className="w-4 h-4 text-amber-600 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18.364 5.636a9 9 0 010 12.728m0 0l-2.829-2.829m2.829 2.829L21 21M15.536 8.464a5 5 0 010 7.072m0 0l-2.829-2.829m-4.243 2.829a4.978 4.978 0 01-1.414-2.83m-1.414 5.658a9 9 0 01-2.167-9.238m7.824 2.167a1 1 0 111.414 1.414m-1.414-1.414L3 3m8.293 8.293l1.414 1.414" />
                </svg>
                <p className="text-sm text-amber-800">Showing an offline copy — reconnect to load the latest.</p>
              </div>
            )}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {reports.map((report) => (
                <Card key={report.id} className="p-6">
                  <h3 className="text-lg font-semibold text-text-main mb-2">
                    {report.report_type.replace('_', ' ')}
                  </h3>
                  {report.report_date && (
                    <p className="text-subtext text-sm mb-2">
                      Date: {new Date(report.report_date).toLocaleDateString()}
                    </p>
                  )}
                  {report.file_name && (
                    <p className="text-subtext text-sm mb-2">File: {report.file_name}</p>
                  )}
                  {report.notes && (
                    <p className="text-subtext text-sm mb-2 italic">Notes: {report.notes}</p>
                  )}
                  <div className="flex gap-2 flex-wrap">
                    <button onClick={() => handleViewReport(report)} className="px-3 py-1.5 rounded-lg bg-primary/10 text-primary font-medium text-sm hover:bg-primary/20 transition-colors">View</button>
                    <button onClick={() => handleLabAnalysis(report)} className="px-3 py-1.5 rounded-lg bg-teal-50 text-teal-700 font-medium text-sm hover:bg-teal-100 transition-colors">Lab Values</button>
                    <button onClick={() => handleExplain(report)} className="px-3 py-1.5 rounded-lg bg-sky-50 text-sky-700 font-medium text-sm hover:bg-sky-100 transition-colors">Explain Simply</button>
                    <button onClick={() => setDigitizedReport(report)} className="px-3 py-1.5 rounded-lg bg-emerald-50 text-emerald-700 font-medium text-sm hover:bg-emerald-100 transition-colors">Digital Report</button>
                    <button onClick={() => handleDownloadPdf(report)} className="px-3 py-1.5 rounded-lg bg-indigo-50 text-indigo-700 font-medium text-sm hover:bg-indigo-100 transition-colors">Download PDF</button>
                    <button onClick={() => handleDelete(report.id)} className="px-3 py-1.5 rounded-lg bg-red-50 text-red-600 font-medium text-sm hover:bg-red-100 transition-colors">Delete</button>
                  </div>
                </Card>
              ))}
            </div>
          </div>
        )}
      </div>

      {viewingReport && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-auto">
            <div className="p-4 border-b flex justify-between items-center">
              <h3 className="font-medium">{viewingReport.name}</h3>
              <button onClick={() => { URL.revokeObjectURL(viewingReport.url); setViewingReport(null); }} className="text-gray-500 hover:text-gray-700">✕</button>
            </div>
            <div className="p-4">
              {viewingReport.name.toLowerCase().endsWith('.pdf') ? (
                <iframe src={viewingReport.url} className="w-full h-[70vh]" title={viewingReport.name} />
              ) : (
                <img src={viewingReport.url} alt={viewingReport.name} className="max-w-full h-auto" />
              )}
            </div>
          </div>
        </div>
      )}

      {digitizedReport && (() => {
        const userData = localStorage.getItem('user');
        const user = userData ? JSON.parse(userData) : { name: 'Unknown', id: '', email: '' };
        return (
          <DigitizedReport
            report={digitizedReport}
            user={user}
            onClose={() => setDigitizedReport(null)}
          />
        );
      })()}

      {/* Lab Values modal */}
      {labAnalysis && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onClick={() => setLabAnalysis(null)}>
          <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-auto shadow-xl" onClick={e => e.stopPropagation()}>
            <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex justify-between items-center">
              <div>
                <h3 className="font-semibold text-gray-900">Lab Values — {labAnalysis.reportName}</h3>
                <p className="text-xs text-subtext">Flagged against typical adult reference ranges (educational)</p>
              </div>
              <button onClick={() => setLabAnalysis(null)} className="text-gray-400 hover:text-gray-600">✕</button>
            </div>
            <div className="p-6">
              {labLoading ? (
                <p className="text-subtext text-center py-8">Analyzing…</p>
              ) : labAnalysis.findings.length === 0 ? (
                <p className="text-subtext text-center py-8">No recognizable lab values found in this report&apos;s text.</p>
              ) : (
                <>
                  <div className="mb-4 flex items-center gap-2">
                    <span className={`text-xs font-semibold px-2 py-1 rounded ${labAnalysis.overall === 'ABNORMAL' ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'}`}>
                      {labAnalysis.overall}
                    </span>
                    <span className="text-sm text-subtext">{labAnalysis.abnormal_count} value(s) outside normal range</span>
                  </div>
                  <div className="space-y-2">
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
                </>
              )}
            </div>
          </div>
        </div>
      )}

      {explain && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onClick={() => setExplain(null)}>
          <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-auto shadow-xl" onClick={e => e.stopPropagation()}>
            <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex justify-between items-center">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-sky-100 rounded-lg flex items-center justify-center">
                  <span className="text-sky-700 text-xs font-bold">AI</span>
                </div>
                <div>
                  <h3 className="font-semibold text-gray-900">In Plain Language — {explain.title}</h3>
                  <p className="text-xs text-subtext">Simplified by MediStore AI · not medical advice</p>
                </div>
              </div>
              <button onClick={() => setExplain(null)} className="text-gray-400 hover:text-gray-600">✕</button>
            </div>
            <div className="p-6">
              {explainLoading ? (
                <div className="flex items-center gap-2 text-subtext py-8 justify-center">
                  <svg className="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  AI is explaining your report…
                </div>
              ) : (
                <p className="text-sm text-text-main whitespace-pre-wrap leading-relaxed">{explain.text}</p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
