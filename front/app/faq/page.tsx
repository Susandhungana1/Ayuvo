import { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'FAQ - MediStore',
  description: 'Frequently asked questions about MediStore — data security, sharing reports, appointments, and how the platform works.',
  robots: { index: true, follow: true },
};

const FAQS = [
  {
    q: 'Is my medical data safe with MediStore?',
    a: 'Yes. Your data is stored securely in an encrypted database, locked behind your account, and never sold or shared without your consent. You control exactly what you share and for how long.',
  },
  {
    q: 'Is MediStore a medical service?',
    a: 'No. MediStore is a storage and management tool for your health records. It does not provide medical advice, diagnosis, or treatment. Always consult a qualified healthcare provider for medical decisions.',
  },
  {
    q: 'Who can see my records?',
    a: 'Only you, unless you deliberately share them. Doctors you book appointments with and caretakers you invite see only what you authorize, and share links expire automatically after the time you choose.',
  },
  {
    q: 'How does sharing a report work?',
    a: 'You generate a secure link with an expiry time and send it to a doctor or family member. The link opens a read-only view of that single report and stops working once it expires.',
  },
  {
    q: 'Is MediStore free?',
    a: 'Yes. Creating an account and using all core features — vitals, medicines, reports, appointments, and sharing — is free.',
  },
  {
    q: 'How do I book an appointment with a doctor?',
    a: 'Browse available doctors, check their availability, pick a free time slot, and confirm. The system validates the slot is still free at the moment you book, so double-booking is prevented.',
  },
  {
    q: 'Can I use MediStore on my phone?',
    a: 'Yes. MediStore has a mobile app for Android and iOS alongside the website, so your records are available wherever you are.',
  },
  {
    q: 'How do I delete my account and data?',
    a: 'Contact us at susandhungana20@gmail.com and we will delete your account and associated data. You can also delete individual records, documents, and reports from within the app at any time.',
  },
];

export default function FaqPage() {
  return (
    <div className="min-h-screen bg-[var(--color-bg)]">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <h1 className="text-3xl font-bold text-[var(--color-ink)] mb-3">Frequently Asked Questions</h1>
        <p className="text-[var(--color-ink-variant)] mb-8">
          Answers to the questions people ask before trusting MediStore with their records.
        </p>

        <div className="space-y-4">
          {FAQS.map((item) => (
            <details key={item.q} className="group bg-white dark:bg-[var(--color-card)] border border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] rounded-[var(--radius-md)]">
              <summary className="flex items-center justify-between gap-4 px-5 py-4 cursor-pointer font-medium text-[var(--color-ink)] list-none">
                {item.q}
                <span className="text-[var(--color-primary)] transition-transform group-open:rotate-45 text-lg leading-none shrink-0">+</span>
              </summary>
              <p className="px-5 pb-5 text-sm text-[var(--color-ink-variant)] leading-relaxed">{item.a}</p>
            </details>
          ))}
        </div>

        <div className="mt-12 pt-6 border-t border-[var(--color-outline-subtle)] flex items-center justify-between">
          <Link href="/" className="text-sm text-[var(--color-primary)] hover:underline">
            &larr; Back to Home
          </Link>
          <p className="text-sm text-[var(--color-ink-variant)]">
            Still have questions?{' '}
            <Link href="/contact" className="text-[var(--color-primary)] hover:underline">Contact us</Link>
          </p>
        </div>
      </div>
    </div>
  );
}