/// A doctor's registration: what is on file, or the form that puts it there.
///
/// `ADD_DOCTOR_GUIDE.txt` documents four steps, of which only one belongs to
/// the doctor. Elevating the account to DOCTOR and setting `verified = true`
/// are `psql` updates an operator runs — a practitioner who could verify
/// themselves is not a verified practitioner — so this screen does step 4 and
/// explains the two it will not do.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/range_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../domain/doctor.dart';
import 'doctor_controllers.dart';

class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(doctorProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor profile')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(doctorProfileProvider.notifier).refresh(),
        child: ListView(
          padding: AppSpacing.screen,
          children: [
            switch (profile) {
              AsyncData(value: HasDoctorProfile(:final doctor)) =>
                _Registered(doctor: doctor),
              AsyncData(value: NoDoctorProfile()) => const _NotRegistered(),
              AsyncData(value: NotADoctor()) => const _NotADoctor(),
              AsyncError(:final error) => ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.read(doctorProfileProvider.notifier).refresh(),
                ),
              _ => const SkeletonCard(lines: 3),
            },
          ],
        ),
      ),
    );
  }
}

class _Registered extends StatelessWidget {
  const _Registered({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: AppSpacing.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor.name, style: context.texts.titleLarge),
                if (doctor.credentials.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(doctor.credentials, style: context.texts.bodyMedium),
                ],
                const SizedBox(height: AppSpacing.md),
                _Field(label: 'NMC number', value: doctor.nmid),
                const SizedBox(height: AppSpacing.md),
                StatusChip(
                  label: doctor.verified
                      ? 'Verified — patients can book you'
                      : 'Awaiting verification',
                  status:
                      doctor.verified ? RangeStatus.ok : RangeStatus.caution,
                ),
              ],
            ),
          ),
        ),
        if (!doctor.verified) ...[
          const SizedBox(height: AppSpacing.md),
          const MessageBanner(
            tone: BannerTone.notice,
            message: 'An administrator checks your registration against the '
                'NMC register before you appear in the directory. Until then '
                'nobody can find you to book.',
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.texts.bodySmall),
        Text(value, style: context.numerals.numericMedium),
      ],
    );
  }
}

class _NotRegistered extends ConsumerWidget {
  const _NotRegistered();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EmptyState(
          icon: Icons.badge_outlined,
          title: 'No registration on file',
          message: 'Add your NMC number and qualification. Nothing else on the '
              'doctor side works until this exists — not your hours, and not '
              'your inbox.',
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () => _showRegistrationSheet(context),
          child: const Text('Add my registration'),
        ),
      ],
    );
  }
}

class _NotADoctor extends StatelessWidget {
  const _NotADoctor();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.lock_outline,
      title: 'This is a patient account',
      message: 'Doctor accounts are set up by a MediStore administrator. '
          'Contact them if you are a practitioner and need one.',
    );
  }
}

Future<void> _showRegistrationSheet(BuildContext context) {
  return showFormSheet<void>(
    context: context,
    builder: (_) => const _RegistrationSheet(),
  );
}

class _RegistrationSheet extends ConsumerStatefulWidget {
  const _RegistrationSheet();

  @override
  ConsumerState<_RegistrationSheet> createState() => _RegistrationSheetState();
}

class _RegistrationSheetState extends ConsumerState<_RegistrationSheet> {
  final _form = GlobalKey<FormState>();
  final _nmid = TextEditingController();
  final _degree = TextEditingController();
  final _specialty = TextEditingController();

  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _nmid.dispose();
    _degree.dispose();
    _specialty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(doctorProfileProvider.notifier).createProfile(
            nmid: _nmid.text.trim(),
            degree: _degree.text.trim(),
            specialty: _specialty.text.trim().isEmpty
                ? null
                : _specialty.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Your registration',
      subtitle: 'An administrator verifies this before patients can book you.',
      submitLabel: 'Save registration',
      busy: _busy,
      error: _error,
      onSubmit: _save,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nmid,
              decoration: const InputDecoration(
                labelText: 'NMC number',
                hintText: 'Nepal Medical Council registration',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'This is what gets verified, so it is required.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _degree,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Qualification',
                hintText: 'MBBS, MD, MS',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Patients pick a doctor by this.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _specialty,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Specialty (optional)',
                hintText: 'Cardiology, paediatrics',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'A registration can only be added once, and this app cannot '
              'change it afterwards.',
              style: context.texts.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
