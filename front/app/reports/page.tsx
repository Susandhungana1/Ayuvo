'use client';

import { useEffect, useState, useRef } from 'react';
import { apiFetch } from '@/lib/api';
import { useRouter } from 'next/navigation';
import { FileText, Pencil, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { StatusChip } from '@/components/ui/status-chip';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/ui/empty-state';
import { Dialog } from '@/components/ui/dialog';
import { LabGauge, parseRange } from '@/components/ui/lab-gauge';
import { generateReportPdf } from '@/lib/reportPdf';
import { cacheGet, cacheSet } from '@/lib/offlineCache';
import { formatPlainDate } from '@/lib/datetime';
import {
  LineChart, Line, XAxis, YAxis, ReferenceArea, ResponsiveContainer,
} from 'recharts';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface Report {
  id: string;
  report_type: string;
  report_date?: string;
  file_name: string;
  notes?: string;
  extracted_text?: string;
  ocr_status?: 'PENDING' | 'DONE' | 'FAILED' | string;
  document_id?: string;
  doctor_name?: string;
  hospital?: string;
}

interface ReportSummary {
  abnormal_count: number;
  names: string[];
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
  reportId: string;
  reportName: string;
  overall: string;
  abnormal_count: number;
  findings: LabFinding[];
}

interface TrendSeries {
  name: string;
  unit: string;
  reference_range: string;
  points: { date: string; value: number; status: string }[];
  first_value: number;
  last_value: number;
  change: number;
  percent_change: number | null;
  direction: 'up' | 'down' | 'flat';
  latest_status: 'HIGH' | 'LOW' | 'NORMAL';
}

const INPUT_CLASS = "flex w-full h-11 rounded-sm border border-outline bg-surface-card px-3.5 text-base text-on-surface placeholder:text-on-surface-variant/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring transition-colors";

function findingChip(status: 'HIGH' | 'LOW' | 'NORMAL') {
  if (status === 'HIGH') return <StatusChip level="alert" label="HIGH" trend="up" />;
  if (status === 'LOW') return <StatusChip level="caution" label="LOW" trend="down" />;
  return <StatusChip level="ok" label="NORMAL" />;
}

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
  const [labAnalysis, setLabAnalysis] = useState<LabAnalysis | null>(null);
  const [labLoading, setLabLoading] = useState(false);
  const [labPending, setLabPending] = useState(false);
  const [trends, setTrends] = useState<TrendSeries[]>([]);
  const [summaries, setSummaries] = useState<Record<string, ReportSummary>>({});
  const [editing, setEditing] = useState<LabFinding | null>(null);
  const [editValue, setEditValue] = useState('');
  const [editUnit, setEditUnit] = useState('');
  const [editSaving, setEditSaving] = useState(false);
  const [editError, setEditError] = useState('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const loadSummaries = async (list: Report[]) => {
    const token = localStorage.getItem('token');
    const results = await Promise.all(
      list.map(async (r) => {
        try {
          const res = await apiFetch(`${API_URL}/api/reports/${r.id}/lab-analysis`, {
            headers: { 'Authorization': `Bearer ${token}` }
          });
          if (!res.ok) return null;
          const data = await res.json();
          const abnormal = (data.findings || []).filter(
            (f: LabFinding) => f.status !== 'NORMAL'
          );
          return {
            id: r.id,
            summary: {
              abnormal_count: abnormal.length,
              names: abnormal.map((f: LabFinding) => f.name),
            },
          };
        } catch { return null; }
      })
    );
    const next: Record<string, ReportSummary> = {};
    for (const row of results) {
      if (row && row.summary.abnormal_count > 0) next[row.id] = row.summary;
    }
    setSummaries(next);
  };

  const loadReports = async (): Promise<{ reports: Report[]; offline: boolean } | null> => {
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/reports`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        const list = data.reports || [];
        cacheSet('reports', list); // keep a local copy for offline viewing
        return { reports: list, offline: false };
      }
      throw new Error('bad response');
    } catch (err) {
      // Network/backend down: fall back to the last cached copy if we have one.
      const cached = await cacheGet<Report[]>('reports');
      if (cached && cached.data.length) return { reports: cached.data, offline: true };
      console.error(err);
      return null;
    }
  };

  const loadTrends = async (): Promise<TrendSeries[]> => {
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/reports/trends`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        return data.series || [];
      }
    } catch (err) { console.error(err); }
    return [];
  };

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    let cancelled = false;
    (async () => {
      const [loaded, series] = await Promise.all([loadReports(), loadTrends()]);
      if (cancelled) return;
      if (loaded !== null) {
        setReports(loaded.reports);
        setOfflineCopy(loaded.offline);
        if (!loaded.offline) loadSummaries(loaded.reports);
      }
      setTrends(series);
      setLoading(false);
    })();
    return () => { cancelled = true; };
  }, [router]);

  const handleLabAnalysis = async (report: Report, retries = 3) => {
    setLabLoading(true);
    setLabPending(report.ocr_status === 'PENDING');
    setLabAnalysis({ reportId: report.id, reportName: report.report_type.replace('_', ' '), overall: '', abnormal_count: 0, findings: [] });
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/reports/${report.id}/lab-analysis`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        // OCR runs in the background after upload — wait for it a little when
        // the report was just created, so "no values" is not shown in error.
        if (data.findings.length === 0 && report.ocr_status === 'PENDING' && retries > 0) {
          await new Promise((r) => setTimeout(r, 2000));
          const fresh = await apiFetch(`${API_URL}/api/reports/${report.id}`, {
            headers: { 'Authorization': `Bearer ${token}` }
          });
          if (fresh.ok) {
            const freshReport = await fresh.json();
            if (freshReport.ocr_status !== 'PENDING') report = freshReport;
          }
          await handleLabAnalysis(report, retries - 1);
          return;
        }
        setLabAnalysis({ reportId: report.id, reportName: report.report_type.replace('_', ' '), ...data });
      }
    } catch (err) { console.error(err); }
    finally { setLabLoading(false); }
  };

  const startEdit = (finding: LabFinding) => {
    setEditing(finding);
    setEditValue(String(finding.value));
    setEditUnit(finding.unit);
    setEditError('');
  };

  const handleSaveEdit = async () => {
    if (!editing || !labAnalysis) return;
    const value = parseFloat(editValue);
    if (Number.isNaN(value)) {
      setEditError('Enter a valid number');
      return;
    }
    setEditSaving(true);
    setEditError('');
    try {
      const token = localStorage.getItem('token');
      const reportId = labAnalysis.reportId;
      if (!reportId) return;
      const res = await apiFetch(`${API_URL}/api/reports/${reportId}/lab-values`, {
        method: 'PUT',
        headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          overrides: {
            [editing.name]: { value, unit: editUnit.trim() || undefined },
          },
        }),
      });
      if (res.ok) {
        const data = await res.json();
        setLabAnalysis({ reportId: labAnalysis.reportId, reportName: labAnalysis.reportName, ...data });
        setEditing(null);
        loadSummaries(reports);
        loadTrends().then(setTrends);
      } else {
        const err = await res.json();
        setEditError(err.detail || 'Failed to save');
      }
    } catch (err) {
      setEditError(err instanceof Error ? err.message : 'Failed to save');
    } finally {
      setEditSaving(false);
    }
  };

  const handleDownloadPdf = async (report: Report) => {
    // Try to enrich the PDF with parsed lab findings; fall back gracefully.
    let findings;
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/reports/${report.id}/lab-analysis`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        findings = data.findings;
      }
    } catch { /* PDF still generates without findings */ }
    generateReportPdf(report, findings);
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
      const res = await apiFetch(`${API_URL}/api/reports`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData
      });
      if (res.ok) {
        const data = await res.json();
        setUploadedReport(data);
        const loaded = await loadReports();
        if (loaded) {
          setReports(loaded.reports);
          setOfflineCopy(loaded.offline);
          if (!loaded.offline) loadSummaries(loaded.reports);
        }
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
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Failed to process file');
    } finally {
      setUploading(false);
    }
  };

  const handleViewReport = async (report: Report) => {
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/reports/${report.id}/file`, {
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
      const res = await apiFetch(`${API_URL}/api/reports/${id}`, {
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
    <div className="min-h-screen bg-surface">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-display font-bold text-on-surface">Medical Reports</h1>
        </div>

        <Card className="p-lg mb-8">
          <h2 className="text-xl font-display font-semibold text-on-surface mb-4">Upload Medical Report</h2>
          <p className="text-on-surface-variant text-sm mb-4">
            Upload a photo or PDF of your report. The text is read out of the
            file so Lab Values can be parsed from it.
          </p>
          <div className="space-y-4">
            <div className="flex flex-col gap-1.5 w-full">
              <label className="text-sm font-semibold text-on-surface">Upload File (Photo/PDF)</label>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*,.pdf"
                onChange={handleFileSelect}
                className={`${INPUT_CLASS} file:mr-4 file:border-0 file:rounded-sm file:bg-primary file:px-4 file:py-2 file:text-sm file:font-medium file:text-on-primary hover:file:bg-primary-pressed`}
              />
              {selectedFile && <p className="text-sm text-on-surface-variant">Selected: {selectedFile.name}</p>}
            </div>

            <div className="flex flex-col gap-1.5 w-full">
              <label className="text-sm font-semibold text-on-surface">Report Type</label>
              <select
                value={reportType}
                onChange={(e) => setReportType(e.target.value)}
                className={INPUT_CLASS}
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
              <label className="text-sm font-semibold text-on-surface">Hospital Name</label>
              <input
                type="text"
                value={hospitalName}
                onChange={(e) => setHospitalName(e.target.value)}
                placeholder="e.g. Bir Hospital, Kathmandu"
                className={INPUT_CLASS}
              />
            </div>

            <div className="flex flex-col gap-1.5 w-full">
              <label className="text-sm font-semibold text-on-surface">Verified By (Doctor)</label>
              <input
                type="text"
                value={verifiedBy}
                onChange={(e) => setVerifiedBy(e.target.value)}
                placeholder="e.g. Dr. Ram Sharma"
                className={INPUT_CLASS}
              />
            </div>

            <div className="flex flex-col gap-1.5 w-full">
              <label className="text-sm font-semibold text-on-surface">Your Notes</label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Add any notes like: This is my annual checkup, I was feeling tired lately..."
                className={`${INPUT_CLASS} min-h-[72px] resize-y py-2.5`}
                rows={3}
              />
            </div>

            <Button onClick={handleUpload} disabled={!selectedFile || uploading} isLoading={uploading}>
              {uploading ? 'Uploading…' : 'Upload Report'}
            </Button>

            {uploadedReport && (
              <div className="flex items-start gap-2 rounded-md bg-ok-container border border-ok/40 px-4 py-3">
                <FileText className="w-5 h-5 text-ok shrink-0 mt-0.5" />
                <p className="text-sm text-ok">
                  Report uploaded. Use <span className="font-medium">Lab Values</span> on the report below to review it.
                </p>
              </div>
            )}
          </div>
        </Card>

        {loading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[1, 2, 3].map((i) => <Skeleton key={i} className="h-48" />)}
          </div>
        ) : reports.length === 0 ? (
          <Card className="p-lg">
            <EmptyState
              icon={FileText}
              title="No medical reports yet"
              description="Upload your first report above — its text is read out of the file so Lab Values can be parsed from it."
            />
          </Card>
        ) : (
          <div>
            {trends.length > 0 && (
              <Card className="p-lg mb-8">
                <h2 className="text-xl font-display font-semibold text-on-surface mb-1">Health Trends</h2>
                <p className="text-on-surface-variant text-sm mb-4">How your lab values have changed across reports over time.</p>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  {trends.map((t) => {
                    const band = parseRange(t.reference_range);
                    return (
                      <div key={t.name} className="border border-outline rounded-sm p-lg">
                        <div className="flex justify-between items-start mb-1">
                          <span className="font-medium text-on-surface text-sm">{t.name}</span>
                          {findingChip(t.latest_status)}
                        </div>
                        <div className="flex items-baseline gap-2">
                          <span className="text-lg font-display font-bold text-on-surface tabular-nums">{t.last_value}</span>
                          <span className="text-xs text-on-surface-variant">{t.unit}</span>
                        </div>
                        {t.points.length > 1 && (
                          <div className="h-16 mt-2">
                            <ResponsiveContainer width="100%" height="100%">
                              <LineChart data={t.points} margin={{ top: 4, right: 2, left: 2, bottom: 0 }}>
                                <YAxis hide domain={['auto', 'auto']} />
                                <XAxis hide dataKey="date" />
                                {band.low !== undefined && band.high !== undefined && (
                                  <ReferenceArea
                                    y1={band.low}
                                    y2={band.high}
                                    fill="var(--color-primary)"
                                    fillOpacity={0.08}
                                    stroke="none"
                                  />
                                )}
                                <Line
                                  type="monotone"
                                  dataKey="value"
                                  stroke="var(--color-primary)"
                                  strokeWidth={2}
                                  dot={{ r: 2.5 }}
                                  isAnimationActive={false}
                                />
                              </LineChart>
                            </ResponsiveContainer>
                          </div>
                        )}
                        <p className="text-xs text-on-surface-variant mt-1 tabular-nums">
                          {t.first_value} → {t.last_value}{' '}
                          <span className={t.direction === 'up' ? 'text-alert' : t.direction === 'down' ? 'text-ok' : 'text-on-surface-variant'}>
                            {t.direction === 'up' ? '▲' : t.direction === 'down' ? '▼' : '—'}{' '}
                            {t.percent_change !== null ? `${Math.abs(t.percent_change)}%` : ''}
                          </span>
                        </p>
                        <p className="text-[11px] text-on-surface-variant mt-1">Normal: {t.reference_range} {t.unit}</p>
                      </div>
                    );
                  })}
                </div>
              </Card>
            )}
            <h2 className="text-xl font-display font-semibold text-on-surface mb-4">Your Reports</h2>
            {offlineCopy && (
              <div className="mb-4 flex items-center gap-2 rounded-md bg-caution-container border border-caution/40 px-4 py-2.5">
                <p className="text-sm text-caution">Showing an offline copy — reconnect to load the latest.</p>
              </div>
            )}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {reports.map((report) => (
                <Card key={report.id} className="p-lg">
                  <h3 className="text-lg font-display font-semibold text-on-surface mb-2">
                    {report.report_type.replace('_', ' ')}
                  </h3>
                  {report.report_date && (
                    <p className="text-on-surface-variant text-sm mb-2">
                      Date: {formatPlainDate(report.report_date)}
                    </p>
                  )}
                  {report.file_name && (
                    <p className="text-on-surface-variant text-sm mb-2">File: {report.file_name}</p>
                  )}
                  {report.notes && (
                    <p className="text-on-surface-variant text-sm mb-2 italic">Notes: {report.notes}</p>
                  )}
                  {summaries[report.id] && (
                    <div className="mb-2 inline-flex items-center gap-1.5 rounded-md bg-alert-container border border-alert/40 px-2.5 py-1">
                      <span className="text-[11px] font-semibold text-alert">
                        {summaries[report.id].abnormal_count} abnormal · {summaries[report.id].names.join(', ')}
                      </span>
                    </div>
                  )}
                  <div className="flex gap-2 flex-wrap">
                    <Button size="sm" variant="secondary" onClick={() => handleViewReport(report)}>View</Button>
                    <Button size="sm" variant="secondary" onClick={() => handleLabAnalysis(report)}>Lab Values</Button>
                    <Button size="sm" variant="secondary" onClick={() => handleDownloadPdf(report)}>Download PDF</Button>
                    <Button size="sm" variant="destructive" onClick={() => handleDelete(report.id)}>Delete</Button>
                  </div>
                </Card>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Report viewer */}
      <Dialog open={viewingReport !== null} onClose={() => { if (viewingReport) URL.revokeObjectURL(viewingReport.url); setViewingReport(null); }} className="max-w-4xl">
        {viewingReport && (
          <>
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-display font-semibold text-on-surface">{viewingReport.name}</h3>
              <button
                onClick={() => { URL.revokeObjectURL(viewingReport.url); setViewingReport(null); }}
                className="text-on-surface-variant hover:text-on-surface transition-colors"
                aria-label="Close"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            {viewingReport.name.toLowerCase().endsWith('.pdf') ? (
              <iframe src={viewingReport.url} className="w-full h-[70vh] rounded-sm border border-outline" title={viewingReport.name} />
            ) : (
              /* eslint-disable-next-line @next/next/no-img-element */
              <img src={viewingReport.url} alt={viewingReport.name} className="max-w-full h-auto rounded-sm border border-outline" />
            )}
          </>
        )}
      </Dialog>

      {/* Lab Values modal */}
      <Dialog open={labAnalysis !== null} onClose={() => setLabAnalysis(null)} className="max-w-2xl">
        {labAnalysis && (
          <>
            <div className="flex items-start justify-between gap-4 mb-4">
              <div>
                <h3 className="font-display font-semibold text-on-surface">Lab Values — {labAnalysis.reportName}</h3>
                <p className="text-xs text-on-surface-variant">Flagged against typical adult reference ranges (educational)</p>
              </div>
              <button onClick={() => setLabAnalysis(null)} className="text-on-surface-variant hover:text-on-surface transition-colors" aria-label="Close">
                <X className="w-5 h-5" />
              </button>
            </div>
            {labLoading ? (
              <div className="space-y-3 py-6">
                <Skeleton className="h-4 w-32" />
                <Skeleton className="h-12" />
                <Skeleton className="h-12" />
              </div>
            ) : labPending ? (
              <p className="text-on-surface-variant text-center py-8">
                Still reading this file — lab values will appear in a moment. Try reopening this window in a few seconds.
              </p>
            ) : labAnalysis.findings.length === 0 ? (
              <p className="text-on-surface-variant text-center py-8">No recognizable lab values found in this report&apos;s text.</p>
            ) : (
              <>
                <div className="mb-4 flex items-center gap-2">
                  <StatusChip level={labAnalysis.overall === 'ABNORMAL' ? 'alert' : 'ok'} label={labAnalysis.overall} />
                  <span className="text-sm text-on-surface-variant">{labAnalysis.abnormal_count} value(s) outside normal range</span>
                </div>
                {editing && (
                  <div className="mb-4 rounded-sm border border-primary/30 bg-primary/5 px-4 py-3">
                    <p className="text-sm font-medium text-on-surface mb-2">
                      Correct value for {editing.name}
                      <span className="text-on-surface-variant font-normal"> — currently {editing.value} {editing.unit}</span>
                    </p>
                    <div className="flex items-center gap-2">
                      <Input
                        type="number"
                        step="any"
                        value={editValue}
                        onChange={(e) => setEditValue(e.target.value)}
                        className="w-32"
                        placeholder="Value"
                        aria-label="Corrected value"
                      />
                      <Input
                        value={editUnit}
                        onChange={(e) => setEditUnit(e.target.value)}
                        className="w-24"
                        placeholder="Unit"
                        aria-label="Unit"
                      />
                      <Button size="sm" onClick={handleSaveEdit} isLoading={editSaving}>Save</Button>
                      <Button size="sm" variant="secondary" onClick={() => setEditing(null)}>Cancel</Button>
                    </div>
                    {editError && <p className="text-alert text-xs mt-2">{editError}</p>}
                  </div>
                )}
                <div className="space-y-2">
                  {labAnalysis.findings.map((f, i) => (
                    <div key={i} className="flex items-center gap-3 border border-outline rounded-sm px-3 py-2.5">
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center justify-between gap-2">
                          <p className="font-medium text-on-surface text-sm truncate">{f.name}</p>
                          <button
                            onClick={() => startEdit(f)}
                            className="text-on-surface-variant hover:text-primary transition-colors"
                            title="Correct this value"
                            aria-label={`Correct ${f.name}`}
                          >
                            <Pencil className="w-3.5 h-3.5" />
                          </button>
                        </div>
                        <LabGauge
                          value={f.value}
                          unit={f.unit}
                          referenceRange={f.reference_range}
                          status={f.status}
                          className="mt-2"
                        />
                        <p className="text-[11px] text-on-surface-variant mt-1">{f.category} · Normal {f.reference_range} {f.unit}</p>
                      </div>
                      <div className="flex flex-col items-end gap-1 shrink-0">
                        <span className="font-semibold text-on-surface text-sm tabular-nums">
                          {f.value} <span className="text-xs text-on-surface-variant">{f.unit}</span>
                        </span>
                        {findingChip(f.status)}
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}
          </>
        )}
      </Dialog>
    </div>
  );
}