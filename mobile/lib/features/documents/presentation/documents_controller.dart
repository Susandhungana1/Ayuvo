/// Documents as state, and the per-document attachment list.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/document_repository.dart';
import '../domain/document.dart';

const _pageSize = 20;

final documentsProvider =
    AsyncNotifierProvider<DocumentsController, List<MedicalDocument>>(
  DocumentsController.new,
);

final documentsTotalProvider = StateProvider<int>((ref) => 0);
final documentsOffsetProvider = StateProvider<int>((ref) => 0);
final documentsLoadingMoreProvider = StateProvider<bool>((ref) => false);

class DocumentsController extends AsyncNotifier<List<MedicalDocument>> {
  DocumentRepository get _repository => ref.read(documentRepositoryProvider);

  @override
  Future<List<MedicalDocument>> build() async {
    if (ref.watch(currentUserProvider) == null) return const [];
    final result = await _repository.list(limit: _pageSize);
    ref.read(documentsTotalProvider.notifier).state = result.total;
    ref.read(documentsOffsetProvider.notifier).state = result.documents.length;
    return result.documents;
  }

  Future<void> refresh() async {
    final result = await _repository.list(limit: _pageSize);
    ref.read(documentsTotalProvider.notifier).state = result.total;
    ref.read(documentsOffsetProvider.notifier).state = result.documents.length;
    state = AsyncData(result.documents);
  }

  Future<void> loadMore() async {
    final currentOffset = ref.read(documentsOffsetProvider);
    ref.read(documentsLoadingMoreProvider.notifier).state = true;
    try {
      final result = await _repository.list(
        offset: currentOffset,
        limit: _pageSize,
      );
      final prev = state.valueOrNull ?? const <MedicalDocument>[];
      state = AsyncData([...prev, ...result.documents]);
      ref.read(documentsOffsetProvider.notifier).state =
          currentOffset + result.documents.length;
      ref.read(documentsTotalProvider.notifier).state = result.total;
    } finally {
      ref.read(documentsLoadingMoreProvider.notifier).state = false;
    }
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
    ref.read(documentsTotalProvider.notifier).state++;
    ref.read(documentsOffsetProvider.notifier).state++;
    return created;
  }

  Future<void> remove(String id) async {
    await _repository.remove(id);
    state = AsyncData([
      for (final document in state.valueOrNull ?? const <MedicalDocument>[])
        if (document.id != id) document,
    ]);
    ref.read(documentsTotalProvider.notifier).state--;
    ref.read(documentsOffsetProvider.notifier).state--;
  }
}

/// `GET /api/documents/{id}/files`, fetched when a document is expanded.
final documentFilesProvider =
    FutureProvider.family<List<DocumentFile>, String>(
  (ref, documentId) =>
      ref.watch(documentRepositoryProvider).files(documentId),
);
