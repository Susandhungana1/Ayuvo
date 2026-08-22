/// Every `/api/documents*` call. Self-only.
///
/// `GET /api/documents` 500'd on every call until it was fixed
/// (`BACKEND_NOTES.md` §0), which means **no client has ever read this list on
/// real data**. Treat its behaviour as unproven and decode defensively.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/time/medi_time.dart';
import '../domain/document.dart';

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(ref.watch(apiClientProvider)),
);

class DocumentRepository {
  const DocumentRepository(this._client);

  final ApiClient _client;

  static const _base = '/api/documents';

  /// `GET /api/documents` — newest visit first.
  Future<({List<MedicalDocument> documents, int total})> list({
    int offset = 0,
    int limit = 20,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      '$_base?offset=$offset&limit=$limit',
    );
    final rows = json['documents'] as List<dynamic>? ?? const [];
    return (
      documents: [
        for (final row in rows)
          MedicalDocument.fromJson(row as Map<String, dynamic>),
      ],
      total: (json['total'] as num?)?.toInt() ?? rows.length,
    );
  }

  /// `POST /api/documents`.
  ///
  /// [visitedOn] is sent as a naive date. Omitted, the server stamps "now" —
  /// which is how every legacy row ended up dated by its upload rather than by
  /// the visit, so the form always asks.
  Future<MedicalDocument> create({
    required String hospital,
    String? location,
    String? doctorName,
    String? department,
    String? description,
    DateTime? visitedOn,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      _base,
      body: {
        'hospital': hospital,
        'location': ?location,
        'doctor_name': ?doctorName,
        'department': ?department,
        'description': ?description,
        if (visitedOn != null) 'checkup_date': MediTime.dateOnly(visitedOn),
      },
    );
    return MedicalDocument.fromJson(json);
  }

  /// `DELETE /api/documents/{id}` — **hard**, and it cascades to every
  /// attachment and its stored bytes. Unlike a medicine, nothing survives.
  Future<void> remove(String id) => _client.delete<void>('$_base/$id');

  /// `GET /api/documents/{id}/files`.
  Future<List<DocumentFile>> files(String documentId) async {
    final json =
        await _client.get<Map<String, dynamic>>('$_base/$documentId/files');
    final rows = json['files'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows) DocumentFile.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// `POST /api/documents/{id}/files` — multipart, 10 MB cap. No OCR and no AI
  /// here, so this one is as fast as the connection.
  Future<DocumentFile> attach(
    String documentId, {
    required String filePath,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final json = await _client.postMultipart<Map<String, dynamic>>(
      '$_base/$documentId/files',
      form,
      onSendProgress: onProgress,
      receiveTimeout: const Duration(minutes: 2),
    );
    return DocumentFile.fromJson(json);
  }

  /// Where an attachment's bytes live. `inline=true` so the server sends
  /// `Content-Disposition: inline`, which is what a viewer wants.
  static String filePath(String documentId, String fileId) =>
      '$_base/$documentId/files/$fileId?inline=true';
}
