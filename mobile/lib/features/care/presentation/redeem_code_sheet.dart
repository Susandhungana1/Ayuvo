/// "Someone gave me a code" — the caretaker half of the pairing.
///
/// The code is short-lived and meant to be read aloud in the same room, so the
/// field is generous, monospaced and upper-cased as you type. Wrong, expired
/// and already-used codes all come back as one identical message from the
/// server, deliberately, so nothing here tries to guess which it was.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_sheet.dart';
import '../data/care_repository.dart';
import '../domain/care_link.dart';
import 'care_controllers.dart';

Future<CareLink?> showRedeemCodeSheet(BuildContext context) {
  return showFormSheet<CareLink>(
    context: context,
    builder: (_) => const RedeemCodeSheet(),
  );
}

class RedeemCodeSheet extends ConsumerStatefulWidget {
  const RedeemCodeSheet({super.key});

  @override
  ConsumerState<RedeemCodeSheet> createState() => _RedeemCodeSheetState();
}

class _RedeemCodeSheetState extends ConsumerState<RedeemCodeSheet> {
  final _code = TextEditingController();

  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await ref
          .read(careLinksProvider(CareRole.caretaker).notifier)
          .redeem(_code.text);
      if (mounted) Navigator.of(context).pop(link);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is CareFailure ? error.message : error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: context.l10n.careRedeemTitle,
      subtitle: context.l10n.careRedeemBlurb,
      submitLabel: context.l10n.careRedeemSubmit,
      busyLabel: context.l10n.caretakersGenerating,
      busy: _busy,
      error: _error,
      onSubmit: _code.text.trim().isEmpty ? null : _submit,
      child: TextField(
        controller: _code,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _code.text.trim().isEmpty ? null : _submit(),
        inputFormatters: [
          // The server accepts the grouped form; typing it in lower case or
          // without the dash is the common case, and both are the caller's
          // problem to normalise, not the user's.
          UpperCaseFormatter(),
          LengthLimitingTextInputFormatter(9),
        ],
        style: context.numerals.numericMedium.copyWith(letterSpacing: 4),
        decoration: InputDecoration(
          labelText: context.l10n.careRedeemLabel,
          hintText: 'XXXX-XXXX',
        ),
      ),
    );
  }
}

/// Upper-cases as the user types, so the field always shows what will be sent.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      // The selection is carried over unchanged: upper-casing never changes the
      // length, so the cursor cannot end up in the wrong place.
      newValue.copyWith(text: newValue.text.toUpperCase());
}
