'use client';

import { useRef } from 'react';

interface DigitizedReportProps {
  report: {
    id: string;
    report_type: string;
    report_date?: string;
    file_name: string;
    notes?: string;
    result_summary?: string;
    ai_report_text?: string;
    doctor_name?: string;
    hospital?: string;
  };
  user: {
    name: string;
    id: string;
    email: string;
    blood_type?: string;
    address?: string;
    city?: string;
  };
  onClose: () => void;
}

export function DigitizedReport({ report, user, onClose }: DigitizedReportProps) {
  const printRef = useRef<HTMLDivElement>(null);

  const handlePrint = () => {
    const printWindow = window.open('', '_blank', 'noopener,noreferrer');
    if (!printWindow) return;
    const content = printRef.current?.innerHTML;
    if (!content) return;
    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Medical Report - ${report.report_type.replace('_', ' ')}</title>
        <style>
          @page { margin: 20mm 15mm; }
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body { font-family: 'Georgia', 'Times New Roman', serif; color: #1a1a1a; padding: 40px; line-height: 1.6; }
          .header { text-align: center; border-bottom: 3px double #1a365d; padding-bottom: 25px; margin-bottom: 30px; }
          .header .brand { font-size: 14px; color: #1a365d; letter-spacing: 3px; text-transform: uppercase; margin-bottom: 5px; }
          .header h1 { font-size: 22px; color: #1a365d; margin-bottom: 5px; }
          .header .report-id { font-size: 11px; color: #666; }
          .section-title { font-size: 14px; font-weight: bold; color: #1a365d; border-bottom: 1px solid #cbd5e0; padding-bottom: 6px; margin-bottom: 12px; text-transform: uppercase; letter-spacing: 1px; }
          table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 12px; border: 1px solid #e2e8f0; border-radius: 8px; }
          th { background: #f1f5f9; padding: 8px 10px; text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; color: #475569; border-bottom: 2px solid #cbd5e0; }
          td { padding: 8px 10px; border-bottom: 1px solid #e2e8f0; }
          tr:nth-child(even) td { background: #f8fafc; }
          .num-cell { font-weight: 700; font-size: 13px; color: #1a1a1a; }
          .abnormal-cell { color: #dc2626 !important; font-weight: 700 !important; }
          .flag { display: inline-flex; align-items: center; justify-content: center; width: 22px; height: 22px; border-radius: 50%; font-size: 11px; font-weight: 700; }
          .flag-high { background: #fee2e2; color: #dc2626; }
          .flag-normal { background: #dcfce7; color: #16a34a; }
          .section-block { margin-bottom: 25px; }
          .section-block h3 { font-size: 13px; font-weight: 700; color: #475569; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 5px; }
          .section-block p { font-size: 13px; color: #374151; line-height: 1.7; white-space: pre-wrap; }
          .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 4px 30px; font-size: 13px; }
          .info-row { display: flex; justify-content: space-between; padding: 2px 0; }
          .info-label { color: #6b7280; }
          .info-value { font-weight: 500; color: #111827; }
          .verification-box { border: 2px dashed #d1d5db; border-radius: 8px; padding: 16px; text-align: center; margin-top: 30px; }
          .verification-box p { font-family: monospace; font-size: 11px; color: #6b7280; }
          .footer-text { text-align: center; font-size: 10px; color: #9ca3af; padding-top: 16px; border-top: 1px solid #e5e7eb; margin-top: 30px; }
          .disclaimer-text { font-size: 11px; color: #9ca3af; font-style: italic; margin-top: 12px; }
        </style>
      </head>
      <body>${content}</body>
      </html>
    `);
    printWindow.document.close();
    printWindow.focus();
    setTimeout(() => printWindow.print(), 500);
  };

  const formatDate = (d?: string) => {
    if (!d) return 'N/A';
    return new Date(d).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
  };

  const reportId = report.id.slice(0, 8).toUpperCase();
  const generatedDate = new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' });

  const parsedSections = report.ai_report_text ? parseAiReportText(report.ai_report_text) : null;

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-xl max-w-4xl w-full max-h-[90vh] overflow-hidden shadow-2xl flex flex-col">
        <div className="flex items-center justify-between px-6 py-4 border-b bg-gray-50 shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-primary rounded-lg flex items-center justify-center">
              <span className="text-white font-bold text-lg">+</span>
            </div>
            <div>
              <h3 className="font-semibold text-gray-900">Digitized Medical Report</h3>
              <p className="text-xs text-gray-500">Official MediStore Document</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={handlePrint}
              className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors flex items-center gap-1.5"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
              </svg>
              Print / Download PDF
            </button>
            <button onClick={onClose} className="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>

        <div className="overflow-y-auto flex-1">
          <div ref={printRef}>
            {/* Header */}
            <div className="text-center border-b-2 border-gray-300 pb-6 mb-6 px-8 pt-8">
              <p className="text-xs tracking-[0.2em] text-gray-500 uppercase mb-1">MediStore</p>
              <h1 className="text-xl font-bold text-gray-900">Digitized Medical Report</h1>
              <p className="text-xs text-gray-400 mt-1">Report ID: MS-{reportId}-{new Date().getFullYear()}</p>
            </div>

            <div className="px-8 pb-8 space-y-6">
              {/* Patient Information */}
              <div>
                <h2 className="text-sm font-bold text-gray-800 border-b border-gray-200 pb-1.5 mb-3 uppercase tracking-wide">Patient Information</h2>
                <div className="grid grid-cols-2 gap-x-8 gap-y-1 text-sm">
                  <div className="flex justify-between"><span className="text-gray-500">Full Name</span><span className="font-medium text-gray-900">{user.name}</span></div>
                  <div className="flex justify-between"><span className="text-gray-500">Patient ID</span><span className="font-medium text-gray-900">{user.id}</span></div>
                  <div className="flex justify-between"><span className="text-gray-500">Email</span><span className="font-medium text-gray-900">{user.email}</span></div>
                  <div className="flex justify-between"><span className="text-gray-500">Blood Type</span><span className="font-medium text-gray-900">{user.blood_type || 'Not specified'}</span></div>
                  {user.address && <div className="flex justify-between"><span className="text-gray-500">Address</span><span className="font-medium text-gray-900">{user.address}</span></div>}
                </div>
              </div>

              {/* Report Details */}
              <div>
                <h2 className="text-sm font-bold text-gray-800 border-b border-gray-200 pb-1.5 mb-3 uppercase tracking-wide">Report Details</h2>
                <div className="grid grid-cols-2 gap-x-8 gap-y-1 text-sm">
                  <div className="flex justify-between"><span className="text-gray-500">Report Type</span><span className="font-medium text-gray-900">{report.report_type.replace('_', ' ')}</span></div>
                  <div className="flex justify-between"><span className="text-gray-500">Report Date</span><span className="font-medium text-gray-900">{formatDate(report.report_date)}</span></div>
                  <div className="flex justify-between"><span className="text-gray-500">File Name</span><span className="font-medium text-gray-900">{report.file_name}</span></div>
                  <div className="flex justify-between"><span className="text-gray-500">Generated On</span><span className="font-medium text-gray-900">{generatedDate}</span></div>
                </div>
              </div>

              {/* Doctor Info */}
              {(report.doctor_name || report.hospital) && (
                <div>
                  <h2 className="text-sm font-bold text-gray-800 border-b border-gray-200 pb-1.5 mb-3 uppercase tracking-wide">Healthcare Provider</h2>
                  <div className="grid grid-cols-2 gap-x-8 gap-y-1 text-sm">
                    {report.doctor_name && <div className="flex justify-between"><span className="text-gray-500">Verified By</span><span className="font-medium text-gray-900">{report.doctor_name}</span></div>}
                    {report.hospital && <div className="flex justify-between"><span className="text-gray-500">Hospital</span><span className="font-medium text-gray-900">{report.hospital}</span></div>}
                  </div>
                </div>
              )}

              {/* Laboratory Test Results */}
              {parsedSections && (
                <div>
                  <h2 className="text-sm font-bold text-gray-800 border-b border-gray-200 pb-1.5 mb-3 uppercase tracking-wide">Laboratory Test Results</h2>
                  <div className="space-y-4">
                    {parsedSections.map((section, i) => (
                      <div key={i}>
                        {section.table ? (
                          <div>
                            <h3 className="text-xs font-semibold text-gray-600 uppercase tracking-wider mb-1.5">{section.title}</h3>
                            <div className="overflow-x-auto rounded-lg border border-gray-200">
                              <table className="w-full text-xs">
                                <thead>
                                  <tr className="bg-gray-100">
                                    {section.table.headers.map((h, j) => (
                                      <th key={j} className="px-3 py-2.5 text-left font-semibold text-gray-600 uppercase tracking-wider">{h}</th>
                                    ))}
                                    <th className="px-3 py-2.5 text-center font-semibold text-gray-600 uppercase tracking-wider w-10">Flag</th>
                                  </tr>
                                </thead>
                                <tbody>
                                  {section.table.rows.map((row, j) => {
                                    const numericalCell = row.find(c => /^\d+\.?\d*/.test(c.value));
                                    const isNumericalRow = numericalCell !== undefined;
                                    return (
                                      <tr key={j} className={j % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                                        {row.map((cell, k) => (
                                          <td key={k} className={`px-3 py-2.5 ${cell.isAbnormal ? 'text-red-600 font-semibold' : isNumericalRow && k === row.indexOf(numericalCell!) ? 'text-gray-900 font-bold text-sm' : 'text-gray-700'}`}>
                                            {cell.value}
                                          </td>
                                        ))}
                                        <td className="px-3 py-2.5 text-center">
                                          {row.some(c => c.isAbnormal) ? (
                                            <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-red-100 text-red-700 text-xs font-bold">H</span>
                                          ) : row.some(c => /^\d+/.test(c.value)) ? (
                                            <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-green-100 text-green-700 text-xs font-bold">N</span>
                                          ) : null}
                                        </td>
                                      </tr>
                                    );
                                  })}
                                </tbody>
                              </table>
                            </div>
                          </div>
                        ) : null}
                      </div>
                    ))}
                  </div>
                  <p className="text-xs text-gray-400 mt-3 italic">This report is AI-generated and should be reviewed by a qualified healthcare professional.</p>
                </div>
              )}

              {/* Verification */}
              <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 text-center">
                <p className="text-xs font-mono text-gray-500">Verification Code: MS-{reportId}-{user.id.slice(-4)}</p>
                <p className="text-xs text-gray-400 mt-1">Generated by MediStore &mdash; Digitized Medical Report</p>
              </div>

              {/* Footer */}
              <div className="text-center text-xs text-gray-400 pt-4 border-t border-gray-200">
                <p>MediStore &mdash; Personal Digital Health Store</p>
                <p className="mt-0.5">This is a computer-generated document. No signature is required.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function parseAiReportText(text: string) {
  const sections = text.split(/(?=--------------------------------------------------------------------------------)/g).filter(s => s.trim());
  return sections.map((section) => {
    const lines = section.split('\n').filter(l => l.trim());
    const headerLine = lines.find(l => l.includes('FORMAL MEDICAL REPORT') || l.includes('PATIENT INFORMATION') || l.includes('REPORT CLASSIFICATION') || l.includes('RESULTS') || l.includes('INTERPRETATION') || l.includes('CLINICAL CORRELATION') || l.includes('RECOMMENDATIONS') || l.includes('CONCLUSION'));
    
    let title = 'Section';
    if (headerLine) {
      if (headerLine.includes('FORMAL MEDICAL REPORT')) title = 'Report Overview';
      else if (headerLine.includes('PATIENT INFORMATION')) title = 'Patient Information';
      else if (headerLine.includes('REPORT CLASSIFICATION')) title = 'Classification';
      else if (headerLine.includes('RESULTS')) title = 'Results & Findings';
      else if (headerLine.includes('INTERPRETATION')) title = 'Interpretation';
      else if (headerLine.includes('CLINICAL CORRELATION')) title = 'Clinical Correlation';
      else if (headerLine.includes('RECOMMENDATIONS')) title = 'Recommendations';
      else if (headerLine.includes('CONCLUSION')) title = 'Conclusion';
    }

    const contentLines = lines.filter(l => !l.includes('---') && !l.includes('FORMAL MEDICAL REPORT') && !headerLine?.includes(l));
    const content = contentLines.map(l => l.replace(/^-\s*/, '').trim()).filter(Boolean).join('\n');

    // Check if content contains table-like data (pipe separated)
    const tableLines = contentLines.filter(l => l.includes('|'));
    if (tableLines.length >= 2) {
      const headers = tableLines[0].split('|').filter(c => c.trim()).map(c => c.trim());
      const rows = tableLines.slice(1).map(row => {
        const cells = row.split('|').filter(c => c.trim());
        return cells.map((cell, i) => {
          const cv = cell.trim().toLowerCase();
          const isAbnormal = cv.includes('below') || cv.includes('above') || cv.includes('outside') || cv.includes('high') || cv.includes('low') || cv.includes('abnormal') || cv.includes('elevated') || cv.includes('decreased');
          return { value: cell.trim(), isAbnormal };
        });
      });
      return { title, content: '', table: { headers, rows } };
    }

    return { title, content, table: null };
  });
}
