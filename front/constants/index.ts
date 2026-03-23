export const MOCK_REPORTS = [
  {
    id: '1',
    name: 'Blood Test Results - Complete Blood Count',
    date: '2026-03-20T10:00:00Z',
    status: 'completed' as const,
    doctor: 'Sarah Jenkins',
    summary: 'Your CBC results are mostly within normal ranges. Hemoglobin and hematocrit levels are slightly elevated, but nothing concerning. White blood cell count is normal, indicating no active infections.\n\nRecommendation: Stay hydrated and follow up in 6 months.',
    extractedText: 'HEMOGLOBIN: 15.2 g/dL (Normal: 13.8-17.2)\nHEMATOCRIT: 45% (Normal: 41-50%)\nWBC: 7.2 k/uL (Normal: 4.5-11.0)\nPLATELETS: 250 k/uL (Normal: 150-400)',
  },
  {
    id: '2',
    name: 'MRI Scan - Lower Back',
    date: '2026-03-22T14:30:00Z',
    status: 'processing' as const,
    doctor: 'Michael Chen',
  },
  {
    id: '3',
    name: 'Annual Physical Examination Notes',
    date: '2026-02-15T09:15:00Z',
    status: 'completed' as const,
    doctor: 'Sarah Jenkins',
    summary: 'Patient is in good overall health. Blood pressure is 120/80. Heart rate 72 bpm. Weight is stable. Recommended continuing current exercise routine and maintaining a balanced diet.',
    extractedText: 'BP: 120/80 mmHg\nHR: 72 bpm\nTemp: 98.6 F\nResp: 16 bpm\nGeneral: Well-appearing adult in no acute distress.',
  },
];

export const MOCK_USERS = [
  { id: '1', name: 'John Doe', email: 'john@example.com', role: 'patient', status: 'active' },
  { id: '2', name: 'Dr. Sarah Jenkins', email: 'sarah@hospital.com', role: 'doctor', status: 'active' },
  { id: '3', name: 'Admin User', email: 'admin@healthportal.com', role: 'admin', status: 'active' },
  { id: '4', name: 'Jane Smith', email: 'jane@example.com', role: 'patient', status: 'inactive' },
];

export const MOCK_BLOG_POSTS = [
  {
    id: '1',
    title: 'Understanding Your Blood Test Results',
    excerpt: 'A comprehensive guide to reading and understanding common markers in your complete blood count and metabolic panel.',
    category: 'Education',
    date: '2026-03-10',
    readTime: '5 min read',
    imageUrl: 'https://images.unsplash.com/photo-1579684385127-1ef15d508118?q=80&w=800&auto=format&fit=crop',
  },
  {
    id: '2',
    title: 'The Future of AI in Healthcare',
    excerpt: 'How artificial intelligence is transforming medical record analysis and patient care outcomes in modern hospitals.',
    category: 'Technology',
    date: '2026-03-15',
    readTime: '8 min read',
    imageUrl: 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?q=80&w=800&auto=format&fit=crop',
  },
  {
    id: '3',
    title: '10 Tips for Better Sleep',
    excerpt: 'Simple lifestyle modifications that can drastically improve your sleep quality and overall cardiovascular health.',
    category: 'Wellness',
    date: '2026-03-18',
    readTime: '4 min read',
    imageUrl: 'https://images.unsplash.com/photo-1512438283307-e89487c0d297?q=80&w=800&auto=format&fit=crop',
  },
];
