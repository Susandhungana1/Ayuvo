/// `taking_times` is a JSON array **encoded as a string**, and this is the only
/// place that knows it.
///
///     "[\"08:00\",\"20:00\"]"   two doses
///     null                       no schedule
///
/// The server's own reader (`app/core/doses.py::parse_times`) degrades to an
/// empty list on anything it can't understand rather than raising, and so does
/// [decode]. A medicine whose `taking_times` is corrupt must still show up in
/// the list — losing its dose chips is a smaller failure than losing the row.
library;

import 'dart:convert';

abstract final class DoseTimes {
  /// Times as `"HH:mm"`, sorted, deduplicated, malformed entries dropped.
  static List<String> decode(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return const [];

    Object? parsed;
    try {
      parsed = jsonDecode(text);
    } on FormatException {
      return const [];
    }
    if (parsed is! List) return const [];

    final times = <String>{};
    for (final entry in parsed) {
      final normalised = normalise(entry);
      if (normalised != null) times.add(normalised);
    }
    final sorted = times.toList()..sort();
    return List.unmodifiable(sorted);
  }

  /// The wire form, or null when there are no times.
  ///
  /// Null rather than `"[]"` on purpose: `PUT /api/medicines/{id}` reads null as
  /// "leave unchanged", so a caller clearing every dose time is a case the
  /// update path has to handle deliberately rather than by accident.
  static String? encode(Iterable<String> times) {
    final clean = <String>{};
    for (final time in times) {
      final normalised = normalise(time);
      if (normalised != null) clean.add(normalised);
    }
    if (clean.isEmpty) return null;
    final sorted = clean.toList()..sort();
    return jsonEncode(sorted);
  }

  /// `"8:5"` → `"08:05"`; anything that isn't a time of day → null.
  ///
  /// Accepts the sloppy forms because the web app wrote these values with an
  /// `<input type="time">` and nothing has ever validated what reached the
  /// column.
  static String? normalise(Object? value) {
    if (value is! String) return null;
    final parts = value.trim().split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  /// Minutes since midnight, for comparing a dose slot against the clock.
  /// Returns null for anything [normalise] rejects.
  static int? minutesOfDay(String hhmm) {
    final normalised = normalise(hhmm);
    if (normalised == null) return null;
    final parts = normalised.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
