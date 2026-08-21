/// The one place a patient-scoped URL is built.
///
/// **Why this file exists.** User ids look like `#hos014`. Interpolated raw into
/// a URL, the `#` starts a fragment, `patient_id` arrives at the server empty,
/// and `resolve_medicine_scope` quietly falls back to the *caller's own*
/// records — so a caretaker's edit silently lands on their own medicine list.
/// There is no error, no 4xx, and no way to notice from the client. The fix is
/// to encode, and the way to keep it fixed is to have exactly one function that
/// can build these URLs, mirroring `scopedUrl` in `front/lib/care.ts`.
///
/// **Scope.** A care link grants medicines and nothing else — list, create,
/// update, delete, restore, intake, interactions, audit. Never vitals, reports,
/// documents, search or the AI chat. If you are reaching for
/// `patientId` outside `features/medicines`, the answer is no.
library;

abstract final class ScopedUrl {
  /// Builds a relative URL with every component percent-encoded.
  ///
  /// [patientId] null or blank means "my own records" and omits the parameter
  /// entirely, which is exactly what the backend treats as unscoped. Null
  /// values in [query] are dropped for the same reason: `?date=null` is not the
  /// same request as no `date` at all.
  static String build(
    String path, {
    String? patientId,
    Map<String, Object?> query = const {},
  }) {
    final params = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: '${entry.value}',
    };

    final id = patientId?.trim();
    if (id != null && id.isNotEmpty) params['patient_id'] = id;

    if (params.isEmpty) return path;
    // Uri does the encoding — `#` becomes %23, spaces become %20. Never build
    // this string by interpolation.
    return Uri(path: path, queryParameters: params).toString();
  }
}
