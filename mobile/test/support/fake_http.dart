/// A dio adapter that answers from a script instead of a network.
///
/// Lets the client's behaviour — headers, 401 handling, form encoding — be
/// tested against real dio machinery without a server.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class RecordedRequest {
  RecordedRequest(this.options, this.body);

  final RequestOptions options;

  /// The encoded request body as it went over the wire.
  final String body;

  String? get authorization => options.headers['Authorization'] as String?;
}

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);

  /// Answers each request. Throw from here to simulate a connection failure.
  final ResponseBody Function(RecordedRequest request) respond;

  final requests = <RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final request = RecordedRequest(options, utf8.decode(bytes));
    requests.add(request);
    return respond(request);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  Object? body, {
  int statusCode = 200,
  Map<String, List<String>> headers = const {},
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...headers,
    },
  );
}
