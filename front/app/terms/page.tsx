import { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Terms of Service - MediStore',
  description: 'Terms of Service for MediStore digital health platform',
  robots: { index: true, follow: true },
};

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-[var(--color-bg)]">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <h1 className="text-3xl font-bold text-[var(--color-ink)] mb-8">Terms of Service</h1>

        <p className="text-[var(--color-ink-variant)] text-sm mb-6">
          Last updated: {new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}
        </p>

        <div className="prose prose-sm max-w-none space-y-6 text-[var(--color-ink-variant)]">
          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">1. Acceptance of Terms</h2>
            <p>
              By accessing or using MediStore, a product of Quorlyn (the &quot;Service&quot;), you agree to be bound by these Terms of Service
              (&quot;Terms&quot;). If you do not agree to all of these Terms, you may not use the Service.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">2. Description of Service</h2>
            <p>
              MediStore is a digital health platform that allows users to store, manage, and share their medical
              records, vital signs, prescriptions, and other health-related information. The Service also enables
              appointment scheduling with healthcare providers.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">3. Medical Disclaimer</h2>
            <p className="font-semibold text-[var(--color-alert)]">
              IMPORTANT: MediStore is not a medical service provider and does not provide medical advice, diagnosis,
              or treatment.
            </p>
            <p className="mt-2">
              The information provided through our platform is for general informational purposes only and is not a
              substitute for professional medical advice. Always consult with a qualified healthcare provider for any
              medical questions or concerns. Never disregard professional medical advice or delay seeking it because
              of something you have read on this platform.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">4. User Accounts</h2>
            <ul className="list-disc pl-6 mt-2 space-y-1">
              <li>You must be at least 13 years old to create an account.</li>
              <li>You are responsible for maintaining the confidentiality of your account credentials.</li>
              <li>You are responsible for all activities that occur under your account.</li>
              <li>You must provide accurate and complete information during registration.</li>
              <li>You must notify us immediately of any unauthorized use of your account.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">5. User Responsibilities</h2>
            <p>When using the Service, you agree not to:</p>
            <ul className="list-disc pl-6 mt-2 space-y-1">
              <li>Use the Service for any unlawful purpose or in violation of any applicable laws.</li>
              <li>Upload content that is false, misleading, or violates the rights of others.</li>
              <li>Attempt to gain unauthorized access to other users&apos; accounts or data.</li>
              <li>Interfere with or disrupt the Service, servers, or networks.</li>
              <li>Use automated tools (bots, scrapers) to access the Service.</li>
              <li>Share your account credentials with third parties.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">6. Data and Privacy</h2>
            <p>
              Your use of the Service is also governed by our{' '}
              <Link href="/privacy" className="text-[var(--color-primary)] hover:underline">
                Privacy Policy
              </Link>
              . By using the Service, you consent to the collection and use of your information as described
              therein.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">7. Intellectual Property</h2>
            <p>
              All content, features, and functionality of the Service are owned by MediStore and are protected by
              copyright, trademark, and other intellectual property laws. You may not reproduce, distribute, modify,
              or create derivative works without our express written permission.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">8. Limitation of Liability</h2>
            <p>
              To the maximum extent permitted by law, MediStore shall not be liable for any indirect, incidental,
              special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred
              directly or indirectly, or any loss of data, use, goodwill, or other intangible losses resulting from:
            </p>
            <ul className="list-disc pl-6 mt-2 space-y-1">
              <li>Your use of or inability to use the Service.</li>
              <li>Any unauthorized access to or use of our servers and/or any personal information stored therein.</li>
              <li>Any errors, mistakes, or inaccuracies of content.</li>
              <li>Personal injury or property damage resulting from your use of the Service.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">9. Termination</h2>
            <p>
              We may terminate or suspend your account and access to the Service immediately, without prior notice
              or liability, for any reason, including breach of these Terms. Upon termination, your right to use
              the Service will cease immediately.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">10. Changes to Terms</h2>
            <p>
              We reserve the right to modify these Terms at any time. We will notify you of any changes by posting
              the new Terms on this page. Your continued use of the Service after any changes constitutes
              acceptance of the new Terms.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">11. Governing Law</h2>
            <p>
              These Terms shall be governed by and construed in accordance with applicable laws, without regard to
              conflict of law principles.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-ink)] mb-3">12. Contact Us</h2>
            <p>
              If you have questions about these Terms, please contact us at:{' '}
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
