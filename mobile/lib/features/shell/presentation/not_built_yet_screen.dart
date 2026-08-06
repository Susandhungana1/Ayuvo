/// A destination that exists in the navigation but not yet in the app.
///
/// Deliberately not a mock: it says which phase builds it rather than showing
/// invented medicines to make a screenshot look finished. Every one of these is
/// deleted as its real screen lands.
library;

import 'package:flutter/material.dart';

import '../../../core/widgets/states.dart';

class NotBuiltYetScreen extends StatelessWidget {
  const NotBuiltYetScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.summary,
    required this.phase,
  });

  final String title;
  final IconData icon;

  /// What this screen will do, in one sentence.
  final String summary;

  /// Which phase of the migration builds it.
  final String phase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: icon,
        title: '$title arrives in $phase',
        message: summary,
      ),
    );
  }
}
