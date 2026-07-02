'use client';

import { useEffect, useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Input } from '@/components/input';
import { FormalReportView } from '@/components/FormalReportView';

const API_URL = 'http://127.0.0.1:3001';

interface Report {
  id: string;
  report_type: string;
  report_date?: string;
  file_name: string;
  notes?: string;
  result_summary?: string;
  extracted_text?: string;
  ai_report_text?: string;
}

export default function Reports() {
  const router = useRouter();
  const [reports, setReports] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [reportType, setReportType] = useState('');
  const [reportDate, setReportDate] = useState('');
  const [notes, setNotes] = useState('');
  const [uploadedReport, setUploadedReport] = useState<Report | null>(null);
  const [viewingReport, setViewingReport] = useState<{url: string; name: string} | null>(null);
  const [viewingAiReport, setViewingAiReport] = useState<{id: string; content: string} | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    fetchReports();
  }, [router]);

  const fetchReports = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/reports`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setReports(data.reports || []);
      }
    } catch (err) {
      console.error(err);
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
              {uploading ? 'AI is reading your report...' : 'Upload & Generate Report'}
            </Button>

            {uploadedReport?.ai_report_text && (
              <div className="mt-6 border rounded-lg overflow-hidden">
                <div className="bg-gray-50 px-6 py-3 border-b flex justify-between items-center">
                  <div className="flex items-center gap-2">
                    <div className="w-6 h-6 bg-purple-100 rounded flex items-center justify-center">
                      <span className="text-purple-700 text-xs font-bold">AI</span>
                    </div>
                    <h3 className="font-semibold text-gray-900">Formal AI Medical Report</h3>
                  </div>
                  <button
                    onClick={() => {
                      const blob = new Blob([uploadedReport.ai_report_text!], { type: 'text/plain' });
                      const url = URL.createObjectURL(blob);
                      const a = document.createElement('a');
                      a.href = url; a.download = `medical-report-${uploadedReport.id.slice(0, 8)}.txt`;
                      a.click(); URL.revokeObjectURL(url);
                    }}
                    className="text-xs text-gray-500 hover:text-gray-700 flex items-center gap-1"
                  >
                    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    Download
                  </button>
                </div>
                <FormalReportView content={uploadedReport.ai_report_text} />
              </div>
            )}
          </div>
        </Card>

        {loading ? (
          <p className="text-subtext">Loading...</p>
        ) : reports.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext mb-4">No medical reports yet</p>
            <p className="text-subtext text-sm">Upload your first report above</p>
          </Card>
        ) : (
          <div>
            <h2 className="text-xl font-semibold text-text-main mb-4">Your Reports</h2>
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
                    <button onClick={() => handleViewReport(report)} className="text-primary text-sm hover:underline">View</button>
                    <button onClick={() => setViewingAiReport({ id: report.id, content: report.ai_report_text || 'No AI report available' })} className="text-purple-600 text-sm hover:underline">AI Report</button>
                    <button onClick={() => handleDelete(report.id)} className="text-red-500 text-sm hover:underline">Delete</button>
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

      {viewingAiReport && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-auto shadow-xl">
            <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex justify-between items-center z-10">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-purple-100 rounded-lg flex items-center justify-center">
                  <svg className="w-4 h-4 text-purple-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                </div>
                <div>
                  <h3 className="font-semibold text-gray-900">Formal AI Medical Report</h3>
                  <p className="text-xs text-gray-500">Generated by HealthTracker AI</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <button
                  onClick={() => {
                    const blob = new Blob([viewingAiReport.content], { type: 'text/plain' });
                    const url = URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url; a.download = `medical-report-${viewingAiReport.id.slice(0, 8)}.txt`;
                    a.click(); URL.revokeObjectURL(url);
                  }}
                  className="text-xs text-gray-500 hover:text-gray-700 flex items-center gap-1"
                >
                  <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  Download
                </button>
                <button onClick={() => setViewingAiReport(null)} className="text-gray-400 hover:text-gray-600">✕</button>
              </div>
            </div>
            <FormalReportView content={viewingAiReport.content} />
          </div>
        </div>
      )}
    </div>
  );
}
