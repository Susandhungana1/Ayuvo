/// The doctor's inbox is not available yet — a placeholder until it ships.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/coming_soon.dart';

class DoctorInboxScreen extends ConsumerWidget {
  const DoctorInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(body: ComingSoonView());
  }
}