/// A URL somebody else is meant to open: as a QR, as text, and as two actions.
///
/// Used by share links and by the emergency ID. Both hand a stranger a way into
/// part of a health record, so both show the whole URL rather than a friendly
/// label — "tap to share" hides what is being handed over.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

class LinkCard extends StatelessWidget {
  const LinkCard({
    super.key,
    required this.url,
    required this.shareSubject,
    this.caption,
    this.showQr = true,
  });

  final String url;

  /// What the OS share sheet calls this — an email subject, a chat preview.
  final String shareSubject;

  /// One line under the QR: what the person scanning it will see.
  final String? caption;

  final bool showQr;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showQr) ...[
          Center(child: QrPanel(data: url)),
          const SizedBox(height: AppSpacing.md),
        ],
        if (caption != null) ...[
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: context.texts.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: AppRadius.sm,
          ),
          child: SelectableText(
            url,
            style: context.texts.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Copy link'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }

  Future<void> _share(BuildContext context) async {
    // The sheet wants to know where it came from on an iPad, where a share
    // sheet is a popover anchored to whatever was tapped.
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        uri: Uri.parse(url),
        subject: shareSubject,
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}

/// The QR itself, on its own white tile.
///
/// **Always dark-on-white, in both themes.** A QR inverted for dark mode is not
/// a styling choice: most scanners assume dark modules on a light background
/// and simply fail on the reverse, which turns a working emergency ID into a
/// code that a paramedic cannot read.
class QrPanel extends StatelessWidget {
  const QrPanel({super.key, required this.data, this.size = 200});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'QR code for this link',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppPalette.white,
          borderRadius: AppRadius.md,
        ),
        child: QrImageView(
          data: data,
          size: size,
          backgroundColor: AppPalette.white,
          // Error correction M: still scannable with a fingerprint or a fold
          // over part of it, without making the modules too fine to print.
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: AppPalette.ink900,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: AppPalette.ink900,
          ),
        ),
      ),
    );
  }
}
