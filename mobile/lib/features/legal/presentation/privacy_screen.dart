/// Privacy Policy screen for the mobile app.
/// Mirrors the web page at /privacy.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            'Last updated: August 16, 2026',
            style: textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: '1. Introduction',
            body: 'Welcome to MediStore, a product of Quorlyn ("we," "our," or "us"). We are committed to protecting your personal information and your right to privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our digital health platform, including our website and mobile application.',
          ),
          _Section(
            title: '2. Information We Collect',
            body: 'We may collect information about you in various ways, including:\n\n'
                '• Personal Data: Name, email address, and other contact information you provide during registration.\n\n'
                '• Health Data: Medical records, vital signs, prescriptions, and other health-related information you upload or input.\n\n'
                '• Usage Data: Information about how you interact with our platform, including access times and features used.\n\n'
                '• Device Data: Device type, operating system, and unique device identifiers.',
          ),
          _Section(
            title: '3. How We Use Your Information',
            body: 'We use the information we collect to:\n\n'
                '• Provide, maintain, and improve our platform and services.\n\n'
                '• Process and manage your medical records and health data.\n\n'
                '• Send you technical notices, updates, and support messages.\n\n'
                '• Respond to your comments, questions, and customer service requests.\n\n'
                '• Detect, prevent, and address technical issues and security vulnerabilities.\n\n'
                '• Comply with legal obligations.',
          ),
          _Section(
            title: '4. Data Storage and Security',
            body: 'Your health data is stored securely in our database and is encrypted in transit and at rest. We implement industry-standard security measures to protect your personal information. However, no method of transmission over the Internet or method of electronic storage is 100% secure, and we cannot guarantee absolute security.',
          ),
          _Section(
            title: '5. Data Sharing',
            body: 'We do not sell your personal information. We may share your information only in the following cases:\n\n'
                '• With your consent: When you explicitly share your records with healthcare providers or other users through our platform.\n\n'
                '• For healthcare purposes: When you share medical records with doctors or caretakers through our sharing feature.\n\n'
                '• Legal requirements: When required by law, regulation, or valid legal process.',
          ),
          _Section(
            title: '6. Data Retention',
            body: 'We retain your personal information only for as long as necessary to provide you with our services and as described in this Privacy Policy. You may request deletion of your account and associated data at any time by contacting us.',
          ),
          _Section(
            title: '7. Your Rights',
            body: 'Depending on your location, you may have the following rights:\n\n'
                '• Access and receive a copy of your personal data.\n\n'
                '• Correct inaccurate or incomplete personal data.\n\n'
                '• Request deletion of your personal data.\n\n'
                '• Object to or restrict processing of your personal data.\n\n'
                '• Data portability — receive your data in a structured, machine-readable format.',
          ),
          _Section(
            title: "8. Children's Privacy",
            body: 'Our platform is not intended for use by children under the age of 13. We do not knowingly collect personal information from children under 13. If you become aware that a child has provided us with personal information, please contact us so we can take steps to delete such information.',
          ),
          _Section(
            title: '9. Changes to This Policy',
            body: 'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new policy on this page and updating the "Last updated" date. You are advised to review this policy periodically for any changes.',
          ),
          _Section(
            title: '10. Contact Us',
            body: 'If you have questions about this Privacy Policy, please contact us at: quorlytechnologies@gmail.com or visit www.quorlyn.com.np',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
