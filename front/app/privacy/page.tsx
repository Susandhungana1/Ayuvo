import { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Privacy Policy - MediStore',
  description: 'Privacy Policy for MediStore digital health platform',
  robots: { index: true, follow: true },
};

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-[var(--color-bg)]">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <h1 className="text-3xl font-bold text-[var(--color-ink)] mb-8">Privacy Policy</h1>

        <p className="text-[var(--color-ink-variant)] text-sm mb-6">
          Last updated: {new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}
        </p>

        <div className="prose prose-sm max-w-none space-y-6 text-[var(--color-ink-variant)]">
          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">1. Introduction</h2>
            <p>
              Welcome to MediStore, a product of Quorlyn (&quot;we,&quot; &quot;our,&quot; or &quot;us&quot;). We are committed to protecting your personal information
              and your right to privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your
              information when you use our digital health platform, including our website and mobile application.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">2. Information We Collect</h2>
            <p>We may collect information about you in various ways, including:</p>
            <ul className="list-disc pl-6 mt-2 space-y-1">
              <li><strong>Personal Data:</strong> Name, email address, and other contact information you provide during registration.</li>
              <li><strong>Health Data:</strong> Medical records, vital signs, prescriptions, and other health-related information you upload or input.</li>
              <li><strong>Usage Data:</strong> Information about how you interact with our platform, including access times and features used.</li>
              <li><strong>Device Data:</strong> Device type, operating system, and unique device identifiers.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">3. How We Use Your Information</h2>
            <p>We use the information we collect to:</p>
            <ul className="list-disc pl-6 mt-2 space-y-1">
              <li>Provide, maintain, and improve our platform and services.</li>
              <li>Process and manage your medical records and health data.</li>
              <li>Send you technical notices, updates, and support messages.</li>
              <li>Respond to your comments, questions, and customer service requests.</li>
              <li>Detect, prevent, and address technical issues and security vulnerabilities.</li>
              <li>Comply with legal obligations.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">4. Data Storage and Security</h2>
            <p>
              Your health data is stored securely in our database and is encrypted in transit and at rest.
              We implement industry-standard security measures to protect your personal information.
              However, no method of transmission over the Internet or method of electronic storage is 100% secure,
              and we cannot guarantee absolute security.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">5. Data Sharing</h2>
            <p>We do not sell your personal information. We may share your information only in the following cases:</p>
            <ul className="list-disc pl-6 mt-2 space-y-1">
              <li><strong>With your consent:</strong> When you explicitly share your records with healthcare providers or other users through our platform.</li>
              <li><strong>For healthcare purposes:</strong> When you share medical records with doctors or caretakers through our sharing feature.</li>
              <li><strong>Legal requirements:</strong> When required by law, regulation, or valid legal process.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">6. Data Retention</h2>
            <p>
              We retain your personal information only for as long as necessary to provide you with our services
              and as described in this Privacy Policy. You may request deletion of your account and associated data
              at any time by contacting us.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">7. Your Rights</h2>
            <p>Depending on your location, you may have the following rights:</p>
            <ul className="list-disc pl-6 mt-2 space-y-1">
              <li>Access and receive a copy of your personal data.</li>
              <li>Correct inaccurate or incomplete personal data.</li>
              <li>Request deletion of your personal data.</li>
              <li>Object to or restrict processing of your personal data.</li>
              <li>Data portability — receive your data in a structured, machine-readable format.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">8. Children&apos;s Privacy</h2>
            <p>
              Our platform is not intended for use by children under the age of 13.
              We do not knowingly collect personal information from children under 13.
              If you become aware that a child has provided us with personal information,
              please contact us so we can take steps to delete such information.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">9. Changes to This Policy</h2>
            <p>
              We may update this Privacy Policy from time to time. We will notify you of any changes by
              posting the new policy on this page and updating the &quot;Last updated&quot; date. You are advised
              to review this policy periodically for any changes.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">10. Contact Us</h2>
            <p>
              If you have questions about this Privacy Policy, please contact us at:{' '}
              <a href="mailto:susandhungana20@gmail.com" className="text-[var(--color-primary)] hover:underline">
                susandhungana20@gmail.com
              </a>{' '}
              or visit{' '}
              <a href="https://www.quorlyn.com.np" target="_blank" rel="noopener noreferrer" className="text-[var(--color-primary)] hover:underline">
                www.quorlyn.com.np
              </a>
              .
            </p>
          </section>
        </div>

        <div className="mt-12 pt-6 border-t border-[var(--color-outline-subtle)]">
          <Link href="/" className="text-sm text-[var(--color-primary)] hover:underline">
            &larr; Back to Home
          </Link>
        </div>
      </div>
    </div>
  );
}
