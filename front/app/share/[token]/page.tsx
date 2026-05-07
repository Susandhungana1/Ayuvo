'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Card } from '@/components/card';
import { Button } from '@/components/button';

const API_URL = 'http://127.0.0.1:3001';

interface SharedReport {
  id: string;
  report_type: string;
  file_name: string;
  file_content: string;
  notes?: string;
  result_summary?: string;
  extracted_text?: string;
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
      
      // Create blob URL from base64 file_content
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
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-6">
          <Button onClick={() => router.push('/auth/login')}>Login to HealthTracker</Button>
        </div>
        
        <Card className="p-6">
          <h1 className="text-2xl font-bold text-text-main mb-4">
            {report?.report_type.replace('_', ' ')}
          </h1>
          
          {fileUrl && (
            <div className="mb-6">
              <p className="text-sm text-subtext mb-2">Original Document</p>
              {report?.file_name?.toLowerCase().endsWith('.pdf') ? (
                <iframe
                  src={fileUrl}
                  className="w-full h-[70vh] border rounded-lg"
                  title={report?.file_name}
                />
              ) : (
                <img
                  src={fileUrl}
                  alt={report?.file_name}
                  className="max-w-full h-auto border rounded-lg"
                />
              )}
            </div>
          )}
          
          <div className="space-y-4">
            <div>
              <p className="text-sm text-subtext">File Name</p>
              <p className="text-text-main">{report?.file_name}</p>
            </div>
            
            {report?.notes && (
              <div>
                <p className="text-sm text-subtext">Notes</p>
                <p className="text-text-main">{report.notes}</p>
              </div>
            )}
            
            {report?.result_summary && (
              <div>
                <p className="text-sm text-subtext">AI Summary</p>
                <p className="text-text-main">{report.result_summary}</p>
              </div>
            )}
          </div>
        </Card>
      </div>
    </div>
  );
}