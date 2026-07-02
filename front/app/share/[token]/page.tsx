'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Card } from '@/components/card';
import { Button } from '@/components/button';
import { FormalReportView } from '@/components/FormalReportView';

const API_URL = 'http://127.0.0.1:3001';

interface SharedReport {
  id: string;
  report_type: string;
  file_name: string;
  file_content: string;
  notes?: string;
  ai_report_text?: string;
  created_at?: string;
}

export default function ViewSharedReport() {
  const params = useParams();
  const router = useRouter();
  const token = params.token as string;
  
  const [report, setReport] = useState<SharedReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [fileUrl, setFileUrl] = useState<string | null>(null);

  useEffect(() => {
    if (token) {
      fetchReport();
    }
  }, [token]);

  const fetchReport = async () => {
    try {
      const res = await fetch(`${API_URL}/api/share/${token}`);
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.detail || 'Link not found or expired');
      }
      const data = await res.json();
      setReport(data);
      
      if (data.file_content) {
        const byteCharacters = atob(data.file_content);
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
          <Button onClick={() => router.push('/auth/login')}>Login to HealthTracker</Button>
        </div>
        
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-text-main mb-1">
            {report?.report_type.replace('_', ' ')}
          </h1>
          {report?.created_at && (
            <p className="text-subtext text-sm">
              Uploaded: {new Date(report.created_at).toLocaleString()}
            </p>
          )}
        </div>

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
              <div className="w-6 h-6 bg-purple-100 rounded flex items-center justify-center">
                <span className="text-purple-700 text-xs font-bold">AI</span>
              </div>
              <h2 className="text-lg font-semibold text-text-main">Formal AI Medical Report</h2>
            </div>
            {report?.ai_report_text ? (
              <div className="max-h-[60vh] overflow-y-auto border rounded-lg">
                <FormalReportView content={report.ai_report_text} />
              </div>
            ) : (
              <p className="text-subtext text-sm">No AI report available for this document.</p>
            )}
          </Card>
        </div>

        {report?.notes && (
          <Card className="p-4 mb-6">
            <p className="text-sm text-subtext">Patient Notes</p>
            <p className="text-text-main italic">{report.notes}</p>
          </Card>
        )}
      </div>
    </div>
  );
}
