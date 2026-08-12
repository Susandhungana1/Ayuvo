/// The card someone reads when you cannot answer them.
///
/// Written for the reader, not the owner: blood type first and largest, then
/// allergies, then conditions, then who to phone. The QR points at a public
/// `front/` page rather than anything in this app — a paramedic holding your
/// phone has no MediStore account and no time to make one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/link_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../domain/emergency_profile.dart';
import 'emergency_controller.dart';

class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(emergencyProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency ID')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(emergencyProfileProvider.notifier).refresh(),
        child: switch (profile) {
          AsyncData(:final value) => _Profile(profile: value),
          AsyncError(:final error) => ListView(
              padding: AppSpacing.screen,
              children: [
                ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.read(emergencyProfileProvider.notifier).refresh(),
                ),
              ],
            ),
          _ => ListView(
              padding: AppSpacing.screen,
              children: const [
                SkeletonCard(lines: 3),
                SizedBox(height: AppSpacing.md),
                SkeletonCard(lines: 2),
              ],
            ),
        },
      ),
    );
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({required this.profile});

  final EmergencyProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(emergencyLinkProvider);

    return ListView(
      padding: AppSpacing.screen,
      children: [
        if (profile.isEmpty)
          const MessageBanner(
            tone: BannerTone.notice,
            message: 'Nothing is filled in yet, so the card and the QR would '
                'show a stranger an empty page. Start with your blood type.',
          )
        else
          _Card(profile: profile),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showDetailsSheet(context, profile),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(profile.isEmpty ? 'Fill in my details' : 'Edit details'),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: Text('People to call', style: context.texts.titleMedium),
            ),
            TextButton.icon(
              onPressed: () => _showContactSheet(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (profile.contacts.isEmpty)
          Text(
            'Nobody listed. Add the person you would want phoned first.',
            style: context.texts.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          )
        else
          Card(
            child: Column(
              children: [
                for (final contact in profile.contacts)
                  _ContactRow(key: ValueKey(contact.id), contact: contact),
              ],
            ),
          ),
        if (link != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Your public card', style: context.texts.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This link needs no password. Print the code and keep it in a '
            'wallet, or show it on screen — whoever scans it sees exactly what '
            'is above.',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: AppSpacing.card,
              child: LinkCard(
                url: link,
                shareSubject: 'My emergency details',
                caption: 'Opens in any browser.',
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

/// The card itself. Deliberately plain: it is read in a hurry, sometimes over
/// someone's shoulder.
class _Card extends StatelessWidget {
  const _Card({required this.profile});

  final EmergencyProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile.hasBloodType) ...[
              Text('Blood type', style: context.texts.bodySmall),
              Text(
                profile.bloodType!.trim(),
                style: context.numerals.numericLarge,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (profile.hasAllergies) ...[
              _Block(
                label: 'Allergies',
                value: profile.allergies!.trim(),
                emphasise: true,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (profile.hasConditions)
              _Block(
                label: 'Conditions',
                value: profile.medicalConditions!.trim(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;

  /// Allergies get the error colour. It is the one field on this card where
  /// missing it does immediate harm, and a chip would make it look optional.
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.texts.bodySmall),
        Text(
          value,
          style: context.texts.bodyLarge?.copyWith(
            color: emphasise ? context.colors.error : null,
            fontWeight: emphasise ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends ConsumerWidget {
  const _ContactRow({super.key, required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(contact.name),
      subtitle: Text('${contact.relationship} · ${contact.phone}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Call ${contact.name}',
            icon: const Icon(Icons.call_outlined),
            onPressed: () => _call(context),
          ),
          IconButton(
            tooltip: 'Remove ${contact.name}',
            icon: Icon(Icons.delete_outline, color: context.colors.error),
            onPressed: () => _confirmRemove(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // Strip the spaces and dashes people type; `tel:` wants digits, `+` and
    // nothing else.
    final digits = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
    final launched = digits.isEmpty
        ? false
        : await launchUrl(Uri(scheme: 'tel', path: digits));
    if (!launched) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't open the dialler for ${contact.phone}")),
      );
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${contact.name}?'),
        content: const Text(
          'They stop appearing on your emergency card straight away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep them'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(emergencyProfileProvider.notifier)
          .removeContact(contact.id);
      messenger.showSnackBar(
        SnackBar(content: Text('${contact.name} removed')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }
}

Future<void> _showDetailsSheet(
  BuildContext context,
  EmergencyProfile profile,
) {
  return showFormSheet<void>(
    context: context,
    builder: (_) => _DetailsSheet(profile: profile),
  );
}

class _DetailsSheet extends ConsumerStatefulWidget {
  const _DetailsSheet({required this.profile});

  final EmergencyProfile profile;

  @override
  ConsumerState<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends ConsumerState<_DetailsSheet> {
  late final TextEditingController _allergies;
  late final TextEditingController _conditions;
  String? _bloodType;

  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _allergies = TextEditingController(text: widget.profile.allergies ?? '');
    _conditions =
        TextEditingController(text: widget.profile.medicalConditions ?? '');
    final blood = widget.profile.bloodType?.trim();
    _bloodType = (blood?.isNotEmpty ?? false) ? blood : null;
  }

  @override
  void dispose() {
    _allergies.dispose();
    _conditions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Empty strings, never nulls: the server reads null as "leave it as it
      // was", so a null here would make clearing a field impossible.
      await ref.read(emergencyProfileProvider.notifier).save(
            bloodType: _bloodType ?? '',
            allergies: _allergies.text.trim(),
            medicalConditions: _conditions.text.trim(),
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
      title: 'Emergency details',
      subtitle: 'Anyone with your QR can read this. Put in what would help '
          'someone treating you, and nothing else.',
      submitLabel: 'Save details',
      busy: _busy,
      error: _error,
      onSubmit: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Blood type', style: context.texts.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final type in bloodTypes)
                ChoiceChip(
                  label: Text(type),
                  selected: type == _bloodType,
                  // Tapping the selected one clears it — the alternative is a
                  // ninth "don't know" chip that means the same thing.
                  onSelected: (selected) => setState(
                    () => _bloodType = selected ? type : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _allergies,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Allergies',
              hintText: 'Penicillin, peanuts, latex',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _conditions,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Conditions',
              hintText: 'Type 1 diabetes, epilepsy',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showContactSheet(BuildContext context) {
  return showFormSheet<void>(
    context: context,
    builder: (_) => const _ContactSheet(),
  );
}

class _ContactSheet extends ConsumerStatefulWidget {
  const _ContactSheet();

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _relationship = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(emergencyProfileProvider.notifier).addContact(
            name: _name.text.trim(),
            relationship: _relationship.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
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
      title: 'Someone to call',
      subtitle: 'Their name and number appear on your public card.',
      submitLabel: 'Add contact',
      busy: _busy,
      error: _error,
      onSubmit: _save,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Who should be called?'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _relationship,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                hintText: 'Wife, son, neighbour',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'It tells whoever calls how to explain themselves.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'A contact without a number cannot be reached.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'Email (optional)'),
            ),
          ],
        ),
      ),
    );
  }
}
