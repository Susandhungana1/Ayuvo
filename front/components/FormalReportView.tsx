export function FormalReportView({ content }: { content: string }) {
  const sections = content.split(/(?=--------------------------------------------------------------------------------)/g);
  return (
    <div className="bg-white p-8 md:p-12 font-serif max-w-4xl mx-auto">
      {sections.map((section, idx) => {
        if (section.includes('FORMAL MEDICAL REPORT')) {
          const lines = section.split('\n').filter(l => l.trim());
          const reportTypeLine = lines.find(l => l.includes('REPORT TYPE'));
          const dateLine = lines.find(l => l.includes('REPORT DATE'));
          return (
            <div key={idx} className="text-center mb-10 pb-8 border-b-2 border-gray-800">
              <div className="text-xs tracking-[0.2em] text-gray-400 uppercase mb-2">HealthTracker AI</div>
              <h1 className="text-2xl font-bold text-gray-900 tracking-tight mb-4">Formal Medical Report</h1>
              <div className="inline-block text-left bg-gray-50 rounded-lg px-6 py-3 text-sm text-gray-600 space-y-1">
                {reportTypeLine && <p><span className="font-semibold text-gray-700">Type:</span> {reportTypeLine.split(':').slice(1).join(':').trim()}</p>}
                {dateLine && <p><span className="font-semibold text-gray-700">Date:</span> {dateLine.split(':').slice(1).join(':').trim()}</p>}
              </div>
            </div>
          );
        }
        if (section.includes('PATIENT INFORMATION')) {
          const c = section.split('\n').filter(l => l.trim() && !l.includes('PATIENT INFORMATION') && !l.includes('---'));
          return (
            <div key={idx} className="mb-8">
              <div className="flex items-center gap-2 mb-3"><div className="w-1 h-6 bg-blue-600 rounded-full"></div><h2 className="text-lg font-bold text-gray-900">1. Patient Information</h2></div>
              <div className="bg-blue-50 rounded-lg px-5 py-4 text-sm text-gray-700 leading-relaxed">{c.map((l, i) => <p key={i} className="mb-1">{l.replace(/^-\s*/, '').trim()}</p>)}</div>
            </div>
          );
        }
        if (section.includes('REPORT CLASSIFICATION')) {
          const c = section.split('\n').filter(l => l.trim() && !l.includes('REPORT CLASSIFICATION') && !l.includes('---'));
          return (
            <div key={idx} className="mb-8">
              <div className="flex items-center gap-2 mb-3"><div className="w-1 h-6 bg-indigo-600 rounded-full"></div><h2 className="text-lg font-bold text-gray-900">2. Report Classification</h2></div>
              <div className="bg-indigo-50 rounded-lg px-5 py-4 text-sm text-gray-700 leading-relaxed">{c.map((l, i) => <p key={i} className="mb-1">{l.replace(/^-\s*/, '').trim()}</p>)}</div>
            </div>
          );
        }
        if (section.includes('RESULTS & FINDINGS') || section.includes('RESULTS AND FINDINGS')) {
          const c = section.split('\n').filter(l => l.trim() && !l.includes('RESULTS') && !l.includes('---'));
          const tableRows = c.filter(l => l.includes('|'));
          const textContent = c.filter(l => !l.includes('|'));
          return (
            <div key={idx} className="mb-8">
              <div className="flex items-center gap-2 mb-3"><div className="w-1 h-6 bg-amber-600 rounded-full"></div><h2 className="text-lg font-bold text-gray-900">3. Results & Findings</h2></div>
              {tableRows.length > 0 && (
                <div className="overflow-x-auto rounded-lg border border-gray-200 mb-3">
                  <table className="w-full text-sm">
                    <thead><tr className="bg-gray-100">{tableRows[0].split('|').filter(c => c.trim()).map((h, i) => (<th key={i} className="px-4 py-2.5 text-left font-semibold text-gray-700 text-xs uppercase tracking-wider">{h.trim()}</th>))}</tr></thead>
                    <tbody>{tableRows.slice(1).map((row, i) => { const cols = row.split('|').filter(c => c.trim()); if (cols.length < 2) return null; const isAbnormal = cols[3]?.toLowerCase().includes('below') || cols[3]?.toLowerCase().includes('above') || cols[3]?.toLowerCase().includes('outside'); return (<tr key={i} className={i % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>{cols.map((c, j) => (<td key={j} className={`px-4 py-2.5 text-gray-700 ${j === 3 && isAbnormal ? 'text-red-600 font-medium' : ''}`}>{c.trim()}</td>))}</tr>); })}</tbody>
                  </table>
                </div>
              )}
              {textContent.map((l, i) => l.trim() && <p key={i} className="text-sm text-gray-700 leading-relaxed mb-1">{l.trim()}</p>)}
            </div>
          );
        }
        if (section.includes('INTERPRETATION')) {
          const c = section.split('\n').filter(l => l.trim() && !l.includes('INTERPRETATION') && !l.includes('---'));
          return (
            <div key={idx} className="mb-8">
              <div className="flex items-center gap-2 mb-3"><div className="w-1 h-6 bg-orange-600 rounded-full"></div><h2 className="text-lg font-bold text-gray-900">4. Interpretation & Analysis</h2></div>
              <div className="bg-orange-50 rounded-lg px-5 py-4 text-sm text-gray-700 leading-relaxed">{c.map((l, i) => <p key={i} className="mb-2">{l.replace(/^-\s*/, '').trim()}</p>)}</div>
            </div>
          );
        }
        if (section.includes('CLINICAL CORRELATION')) {
          const c = section.split('\n').filter(l => l.trim() && !l.includes('CLINICAL CORRELATION') && !l.includes('---'));
          return (
            <div key={idx} className="mb-8">
              <div className="flex items-center gap-2 mb-3"><div className="w-1 h-6 bg-teal-600 rounded-full"></div><h2 className="text-lg font-bold text-gray-900">5. Clinical Correlation</h2></div>
              <div className="bg-teal-50 rounded-lg px-5 py-4 text-sm text-gray-700 leading-relaxed">{c.map((l, i) => <p key={i} className="mb-2">{l.replace(/^-\s*/, '').trim()}</p>)}</div>
            </div>
          );
        }
        if (section.includes('RECOMMENDATIONS') || section.includes('FOLLOW-UP')) {
          const c = section.split('\n').filter(l => l.trim() && !l.includes('RECOMMENDATIONS') && !l.includes('FOLLOW-UP') && !l.includes('---'));
          return (
            <div key={idx} className="mb-8">
              <div className="flex items-center gap-2 mb-3"><div className="w-1 h-6 bg-green-600 rounded-full"></div><h2 className="text-lg font-bold text-gray-900">6. Recommendations & Follow-up</h2></div>
              <div className="bg-green-50 rounded-lg px-5 py-4 text-sm text-gray-700 leading-relaxed">{c.map((l, i) => { const t = l.replace(/^-\s*/, '').trim(); return t.startsWith('-') ? <p key={i} className="mb-2 ml-4">{t}</p> : <p key={i} className="mb-2">{t}</p>; })}</div>
            </div>
          );
        }
        if (section.includes('CONCLUSION')) {
          const c = section.split('\n').filter(l => l.trim() && !l.includes('CONCLUSION') && !l.includes('---'));
          return (
            <div key={idx} className="mb-8">
              <div className="flex items-center gap-2 mb-3"><div className="w-1 h-6 bg-purple-600 rounded-full"></div><h2 className="text-lg font-bold text-gray-900">7. Conclusion</h2></div>
              <div className="bg-purple-50 rounded-lg px-5 py-4 text-sm text-gray-700 leading-relaxed border-l-4 border-purple-300">{c.map((l, i) => <p key={i} className="mb-2">{l.replace(/^-\s*/, '').trim()}</p>)}</div>
            </div>
          );
        }
        return null;
      })}
      <div className="mt-10 pt-6 border-t border-gray-200 text-center text-xs text-gray-400">
        <p>Generated by HealthTracker AI &mdash; This report is AI-generated and should be reviewed by a healthcare professional.</p>
      </div>
    </div>
  );
}
