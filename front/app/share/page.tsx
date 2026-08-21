'use client';

import { useEffect, useState } from 'react';
import { apiFetch, API_URL } from '@/lib/api';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { QRCodeSVG } from 'qrcode.react';
import { KeptByOthers } from '@/components/kept-by-others';
import { formatServerDateTime, hasExpired } from '@/lib/datetime';



interface Report {
  id: string;
  report_type: string;
  file_name: string;
  notes?: string;
}

interface ShareLink {
  token: string;
  report_id: string;
  expires_at: string;
}

export default function Share() {
  const router = useRouter();
  const [reports, setReports] = useState<Report[]>([]);
  const [shareLinks, setShareLinks] = useState<ShareLink[]>([]);
  const [loading, setLoading] = useState(true);
  const [qrCode, setQrCode] = useState<string | null>(null);
  const [qrPin, setQrPin] = useState<string | null>(null);
  const [qrModalOpen, setQrModalOpen] = useState(false);
  const [reportQrModal, setReportQrModal] = useState<{reportId: string; reportName: string; url: string} | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/auth/login');
      return;
    }
    fetchData();
  }, [router]);

  const fetchData = async () => {
    try {
      const token = localStorage.getItem('token');
      
      const [reportsRes, linksRes] = await Promise.all([
        apiFetch(`${API_URL}/api/reports`, { headers: { 'Authorization': `Bearer ${token}` } }),
        apiFetch(`${API_URL}/api/share`, { headers: { 'Authorization': `Bearer ${token}` } })
      ]);

      if (reportsRes.ok) {
        const data = await reportsRes.json();
        setReports(data.reports || []);
      }

      if (linksRes.ok) {
        const data = await linksRes.json();
        setShareLinks(data.links || []);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleShare = async (reportId: string) => {
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/share/${reportId}`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        const link = `${window.location.origin}/share/${data.token}`;
        await navigator.clipboard.writeText(link);
        alert('Share link copied to clipboard!');
        fetchData();
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleDelete = async (token: string) => {
    if (!confirm('Are you sure you want to revoke this share link?')) return;
    try {
      const tokenAuth = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/share/${token}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${tokenAuth}` }
      });
      if (res.ok) {
        fetchData();
        alert('Share link revoked');
      } else {
        const err = await res.json();
        alert(err.detail || 'Failed to revoke share link');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleGenerateQRCode = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/share/qr-code`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        const qrUrl = `${window.location.origin}/share/qr-code/${data.token}`;
        setQrCode(qrUrl);
        setQrPin(data.pin ?? null);
        setQrModalOpen(true);
      } else {
        const data = await res.json();
        alert(data.detail || 'Failed to generate QR code');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleReportQR = async (reportId: string, reportName: string) => {
    try {
      const token = localStorage.getItem('token');
      const res = await apiFetch(`${API_URL}/api/share/${reportId}`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        const url = `${window.location.origin}/share/${data.token}`;
        setReportQrModal({ reportId, reportName, url });
      } else {
        alert('Failed to create share link');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const getReportType = (reportId: string) => {
    if (reportId === '__ALL_REPORTS__') return 'All Reports (QR Code)';
    const report = reports.find(r => r.id === reportId);
    return report ? report.report_type.replace('_', ' ') : 'Unknown';
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-subtext">Loading...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-text-main">Share Records</h1>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-2 gap-8">
          <div>
            <h2 className="text-xl font-semibold text-text-main mb-4">Available Reports</h2>
            {reports.length === 0 ? (
              <Card className="p-8 text-center">
                <p className="text-subtext">No reports to share</p>
              </Card>
            ) : (
          <div className="space-y-4">
                {reports.map((report) => (
                  <Card key={report.id} className="p-4">
                    <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
                      <div className="min-w-0">
                        <h3 className="font-semibold text-text-main text-sm sm:text-base truncate">
                          {report.report_type.replace('_', ' ')}
                        </h3>
                        <p className="text-subtext text-xs sm:text-sm truncate">{report.file_name}</p>
                      </div>
                      <div className="flex gap-2 w-full sm:w-auto">
                        <button onClick={() => handleReportQR(report.id, report.report_type.replace('_', ' '))}
                          className="text-xs sm:text-sm text-gray-600 hover:text-primary px-2 py-1.5 border rounded flex-1 sm:flex-none text-center">
                          QR
                        </button>
                        <Button onClick={() => handleShare(report.id)} className="text-xs sm:text-sm flex-1 sm:flex-none">
                          Generate Link
                        </Button>
                      </div>
                    </div>
                  </Card>
                ))}
              </div>
            )}
          </div>

          <div>
            <h2 className="text-xl font-semibold text-text-main mb-4">Active Share Links</h2>
            {shareLinks.length === 0 ? (
              <Card className="p-8 text-center">
                <p className="text-subtext">No active share links</p>
              </Card>
            ) : (
              <div className="space-y-4">
                {shareLinks.map((link) => {
                  // The API returns every link the user owns, expired ones
                  // included. An expired link opens to "410 Share link expired"
                  // for the recipient, so listing it as though it still works —
                  // beside a live Revoke button — is actively misleading.
                  const expired = hasExpired(link.expires_at);
                  return (
                    <Card key={link.token} className={`p-4 ${expired ? 'opacity-60' : ''}`}>
                      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2">
                        <div className="min-w-0">
                          <div className="flex items-center gap-2">
                            <p className="font-semibold text-text-main text-sm sm:text-base truncate">
                              {getReportType(link.report_id)}
                            </p>
                            {expired && (
                              <span className="shrink-0 text-[10px] font-semibold uppercase tracking-wide px-1.5 py-0.5 rounded bg-gray-100 text-gray-600">
                                Expired
                              </span>
                            )}
                          </div>
                          <p className="text-subtext text-xs sm:text-sm">
                            {expired ? 'Expired' : 'Expires'}: {formatServerDateTime(link.expires_at)}
                          </p>
                        </div>
                        <button
                          onClick={() => handleDelete(link.token)}
                          className="px-3 py-1.5 rounded-lg bg-red-50 text-red-600 font-medium text-sm hover:bg-red-100 transition-colors self-start sm:self-auto"
                        >
                          {expired ? 'Remove' : 'Revoke'}
                        </button>
                      </div>
                    </Card>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        <div className="mt-8">
          <Card className="p-4 sm:p-6">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-4">
              <div>
                <h3 className="text-base sm:text-lg font-semibold text-text-main">Share All Reports via QR Code</h3>
                <p className="text-subtext text-xs sm:text-sm mt-1">
                  Generate a QR code that contains all your medical reports plus
                  your emergency details (blood type and
                  emergency contacts)
                </p>
              </div>
              <Button onClick={handleGenerateQRCode} disabled={reports.length === 0} className="w-full sm:w-auto">
                Generate QR Code
              </Button>
            </div>
          </Card>
        </div>

        <div className="mt-8">
          <Card className="p-4 sm:p-6">
            <h3 className="text-base sm:text-lg font-semibold text-text-main mb-2">How it works</h3>
            <ul className="text-subtext text-sm space-y-2">
              <li>1. Select a report from your available reports</li>
              <li>2. Click "Generate Link" to create a secure share link</li>
              <li>3. Copy the link and share it with your doctor</li>
              <li>4. The link will expire automatically after 24 hours</li>
              <li>5. You can revoke the link at any time</li>
              <li>6. Use QR Code to share all reports at once — the reader asks for the 6-digit PIN that comes with it</li>
              <li>
                7. A recipient signed in to MediStore can save the share to keep
                it after the link expires — you&apos;ll see them listed below
              </li>
            </ul>
          </Card>
        </div>

        {/* Renders nothing unless someone has kept a copy of these records. */}
        <KeptByOthers />
      </div>

      {qrModalOpen && qrCode && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-md w-full p-6 text-center">
            <h2 className="text-xl font-bold text-text-main mb-4">Scan to View All Reports</h2>
            <div className="flex justify-center mb-4 p-4 bg-white">
              <QRCodeSVG value={qrCode} size={200} />
            </div>
            {qrPin && (
              <div className="mb-4 rounded-lg bg-amber-50 border border-amber-200 p-3">
                <p className="text-sm font-semibold text-amber-800 mb-1">PIN: {qrPin}</p>
                <p className="text-xs text-amber-700">
                  Whoever scans this code will be asked for this PIN. Give it to
                  them separately — do not print it on the same page as the code.
                </p>
              </div>
            )}
            <p className="text-subtext text-sm mb-4">
              Scan this QR code to view all your medical reports and emergency
              details — blood type and your emergency
              contacts
            </p>
            <p className="text-subtext text-xs mb-4">Link: {qrCode}</p>
            <div className="flex gap-2 justify-center">
              <Button onClick={() => navigator.clipboard.writeText(qrCode).then(() => alert('Link copied!'))}>
                Copy Link
              </Button>
              <Button onClick={() => setQrModalOpen(false)} variant="secondary">
                Close
              </Button>
            </div>
          </div>
        </div>
      )}

      {reportQrModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-md w-full p-6 text-center">
            <h2 className="text-xl font-bold text-text-main mb-4">QR Code for {reportQrModal.reportName}</h2>
            <div className="flex justify-center mb-4 p-4 bg-white">
              <QRCodeSVG value={reportQrModal.url} size={200} />
            </div>
            <p className="text-subtext text-sm mb-4">Scan this QR code to view this report</p>
            <p className="text-subtext text-xs mb-4">Link: {reportQrModal.url}</p>
            <div className="flex gap-2 justify-center">
              <Button onClick={() => navigator.clipboard.writeText(reportQrModal.url).then(() => alert('Link copied!'))}>
                Copy Link
              </Button>
              <Button onClick={() => setReportQrModal(null)} variant="secondary">
                Close
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}