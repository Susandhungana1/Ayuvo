/// Terms of Service screen for the mobile app.
/// Mirrors the web page at /terms.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
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
            title: '1. Acceptance of Terms',
            body: 'By accessing or using MediStore (the "Service"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to all of these Terms, you may not use the Service.',
          ),
          _Section(
            title: '2. Description of Service',
            body: 'MediStore is a digital health platform that allows users to store, manage, and share their medical records, vital signs, prescriptions, and other health-related information. The Service also enables appointment scheduling with healthcare providers.',
          ),
          _Section(
            title: '3. Medical Disclaimer',
            body: 'IMPORTANT: MediStore is not a medical service provider and does not provide medical advice, diagnosis, or treatment.\n\n'
                'The information provided through our platform is for general informational purposes only and is not a substitute for professional medical advice. Always consult with a qualified healthcare provider for any medical questions or concerns. Never disregard professional medical advice or delay seeking it because of something you have read on this platform.',
            isWarning: true,
          ),
          _Section(
            title: '4. User Accounts',
            body: '• You must be at least 13 years old to create an account.\n\n'
                '• You are responsible for maintaining the confidentiality of your account credentials.\n\n'
                '• You are responsible for all activities that occur under your account.\n\n'
                '• You must provide accurate and complete information during registration.\n\n'
                '• You must notify us immediately of any unauthorized use of your account.',
          ),
          _Section(
            title: '5. User Responsibilities',
            body: 'When using the Service, you agree not to:\n\n'
                '• Use the Service for any unlawful purpose or in violation of any applicable laws.\n\n'
                '• Upload content that is false, misleading, or violates the rights of others.\n\n'
                '• Attempt to gain unauthorized access to other users\' accounts or data.\n\n'
                '• Interfere with or disrupt the Service, servers, or networks.\n\n'
                '• Use automated tools (bots, scrapers) to access the Service.\n\n'
                '• Share your account credentials with third parties.',
          ),
          _Section(
            title: '6. Data and Privacy',
            body: 'Your use of the Service is also governed by our Privacy Policy. By using the Service, you consent to the collection and use of your information as described therein.',
          ),
          _Section(
            title: '7. Intellectual Property',
            body: 'All content, features, and functionality of the Service are owned by MediStore and are protected by copyright, trademark, and other intellectual property laws. You may not reproduce, distribute, modify, or create derivative works without our express written permission.',
          ),
          _Section(
            title: '8. Limitation of Liability',
            body: 'To the maximum extent permitted by law, MediStore shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses resulting from:\n\n'
                '• Your use of or inability to use the Service.\n\n'
                '• Any unauthorized access to or use of our servers and/or any personal information stored therein.\n\n'
                '• Any errors, mistakes, or inaccuracies of content.\n\n'
                '• Personal injury or property damage resulting from your use of the Service.',
          ),
          _Section(
            title: '9. Termination',
            body: 'We may terminate or suspend your account and access to the Service immediately, without prior notice or liability, for any reason, including breach of these Terms. Upon termination, your right to use the Service will cease immediately.',
          ),
          _Section(
            title: '10. Changes to Terms',
            body: 'We reserve the right to modify these Terms at any time. We will notify you of any changes by posting the new Terms on this page. Your continued use of the Service after any changes constitutes acceptance of the new Terms.',
          ),
          _Section(
            title: '11. Governing Law',
            body: 'These Terms shall be governed by and construed in accordance with applicable laws, without regard to conflict of law principles.',
          ),
          _Section(
            title: '12. Contact Us',
            body: 'If you have questions about these Terms, please contact us at: susandhungana20@gmail.com',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.body,
    this.isWarning = false,
  });

  final String title;
  final String body;
  final bool isWarning;

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
              color: isWarning
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
