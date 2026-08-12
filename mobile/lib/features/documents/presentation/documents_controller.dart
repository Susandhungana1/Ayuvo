/// Documents as state, and the per-document attachment list.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/document_repository.dart';
import '../domain/document.dart';

final documentsProvider =
    AsyncNotifierProvider<DocumentsController, List<MedicalDocument>>(
  DocumentsController.new,
);

class DocumentsController extends AsyncNotifier<List<MedicalDocument>> {
  DocumentRepository get _repository => ref.read(documentRepositoryProvider);

  @override
  Future<List<MedicalDocument>> build() async {
    if (ref.watch(currentUserProvider) == null) return const [];
    return _repository.list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.list);
  }

  Future<MedicalDocument> add({
    required String hospital,
    String? location,
    String? doctorName,
    String? department,
    String? description,
    DateTime? visitedOn,
  }) async {
    final created = await _repository.create(
      hospital: hospital,
      location: location,
      doctorName: doctorName,
      department: department,
      description: description,
      visitedOn: visitedOn,
    );
    // Ordered by visit date descending, and a visit can be backdated.
    final list = [...state.valueOrNull ?? const <MedicalDocument>[], created]
      ..sort((a, b) {
        final left = a.visited;
        final right = b.visited;
        if (left == null || right == null) return 0;
        return right.compareTo(left);
      });
    state = AsyncData(list);
    return created;
  }

  Future<void> remove(String id) async {
    await _repository.remove(id);
    state = AsyncData([
      for (final document in state.valueOrNull ?? const <MedicalDocument>[])
        if (document.id != id) document,
    ]);
  }
}

/// `GET /api/documents/{id}/files`, fetched when a document is expanded.
final documentFilesProvider =
    FutureProvider.family<List<DocumentFile>, String>(
  (ref, documentId) =>
      ref.watch(documentRepositoryProvider).files(documentId),
);
