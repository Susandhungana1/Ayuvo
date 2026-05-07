'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Card } from '@/components/card';
import { Button } from '@/components/button';

const API_URL = 'http://127.0.0.1:3001';

interface Report {
  id: string;
  report_type: string;
  file_name: string;
  file_content: string;
  notes?: string;
  result_summary?: string;
}

interface AllReportsData {
  user_name: string;
  reports: Report[];
}

export default function ViewAllSharedReports() {
  const params = useParams();
  const router = useRouter();
  const token = params.token as string;
  
  const [data, setData] = useState<AllReportsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [viewingReport, setViewingReport] = useState<{url: string; name: string} | null>(null);

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
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-6">
          <Button onClick={() => router.push('/auth/login')}>Login to HealthTracker</Button>
        </div>
        
        <h1 className="text-2xl font-bold text-text-main mb-2">
          Medical Reports from {data?.user_name}
        </h1>
        <p className="text-subtext mb-6">Total: {data?.reports.length} report(s)</p>
        
        {data?.reports.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext">No reports available</p>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {data?.reports.map((report) => (
              <Card key={report.id} className="p-4">
                <div className="flex justify-between items-start mb-2">
                  <div>
                    <h3 className="font-semibold text-text-main">
                      {report.report_type.replace('_', ' ')}
                    </h3>
                    <p className="text-subtext text-sm">{report.file_name}</p>
                  </div>
                  <Button onClick={() => handleViewReport(report)}>
                    View
                  </Button>
                </div>
                {report.notes && (
                  <p className="text-subtext text-sm mt-2">{report.notes}</p>
                )}
                {report.result_summary && (
                  <div className="mt-2 p-2 bg-green-50 rounded text-sm">
                    <p className="font-medium text-green-800">AI Summary:</p>
                    <p className="text-green-700">{report.result_summary}</p>
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