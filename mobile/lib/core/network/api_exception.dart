/// One failure type for the whole app.
///
/// Every repository throws this and nothing else, so a screen never has to know
/// that dio exists. The `message` is written to be shown to a person: it says
/// what failed and, where there is one, what to do about it — never
/// "Something went wrong", and never a stack trace or a raw exception string.
///
/// It also carries no health data. FastAPI's `detail` is a developer-authored
/// string (`"Email already registered"`, `"Invalid credentials"`), not a record
/// out of the database, so passing it through is safe; response *bodies* are
/// never folded into the message.
library;

import 'package:dio/dio.dart';

enum ApiErrorKind {
  /// The phone could not reach the server at all.
  network,

  /// Reached it, but it took too long.
  timeout,

  /// 401 on an authenticated call — the session is over.
  unauthorized,

  /// 401 on sign-in with `X-2FA-Required: true` — collect the code and resubmit.
  twoFactorRequired,

  /// 401 on sign-in without that header — the credentials are wrong.
  credentials,

  /// 403.
  forbidden,

  /// 404.
  notFound,

  /// 400 / 409 / 422 — the request was understood and refused.
  invalid,

  /// 429. slowapi limits register to 5/min, login 10/min, forgot-password 3/min.
  rateLimited,

  /// 5xx.
  server,

  /// Anything else, including a response that did not parse.
  unknown,
}

class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode, this.detail});

  final ApiErrorKind kind;

  /// Shown to the user as-is.
  final String message;

  final int? statusCode;

  /// The server's own `detail`, kept for logs and tests. Not always shown.
  final String? detail;

  bool get isUnauthorized => kind == ApiErrorKind.unauthorized;

  /// Whether offering a Retry button makes sense. Re-sending a request the
  /// server has already refused on its merits does not.
  bool get isRetryable => switch (kind) {
        ApiErrorKind.network ||
        ApiErrorKind.timeout ||
        ApiErrorKind.server ||
        ApiErrorKind.unknown =>
          true,
        _ => false,
      };

  static ApiException from(Object error, [StackTrace? _]) {
    if (error is ApiException) return error;
    if (error is DioException) return _fromDio(error);
    return const ApiException(
      ApiErrorKind.unknown,
      "Something failed that shouldn't have. Try again.",
    );
  }

  static ApiException _fromDio(DioException error) {
    final response = error.response;
    final status = response?.statusCode;
    final detail = _detailOf(response?.data);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          ApiErrorKind.timeout,
          'The server took too long to answer. Try again.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        if (response == null) {
          return const ApiException(
            ApiErrorKind.network,
            "Couldn't reach Ayuvo. Check your connection and try again.",
          );
        }
      case DioExceptionType.cancel:
        return const ApiException(ApiErrorKind.unknown, 'Request cancelled.');
      case DioExceptionType.badCertificate:
        return const ApiException(
          ApiErrorKind.network,
          "Couldn't verify the server's certificate.",
        );
      case DioExceptionType.badResponse:
        break;
    }

    if (status == 401) {
      // The header is the server's way of saying "credentials were fine, now
      // prove the second factor" — see server/app/api/auth.py::login.
      final needs2fa =
          response?.headers.value('x-2fa-required')?.toLowerCase() == 'true';
      if (needs2fa) {
        return ApiException(
          ApiErrorKind.twoFactorRequired,
          'Enter the 6-digit code from your authenticator app.',
          statusCode: status,
          detail: detail,
        );
      }
      // Whether this ends the session or just fails a sign-in is the caller's
      // call: ApiClient turns it into `unauthorized` for authenticated routes.
      return ApiException(
        ApiErrorKind.credentials,
        detail ?? 'Your email or password is incorrect.',
        statusCode: status,
        detail: detail,
      );
    }

    return switch (status) {
      403 => ApiException(
          ApiErrorKind.forbidden,
          detail ?? "You don't have access to that.",
          statusCode: status,
          detail: detail,
        ),
      404 => ApiException(
          ApiErrorKind.notFound,
          detail ?? "That isn't here any more.",
          statusCode: status,
          detail: detail,
        ),
      429 => ApiException(
          ApiErrorKind.rateLimited,
          'Too many attempts. Wait a minute and try again.',
          statusCode: status,
          detail: detail,
        ),
      final int s when s >= 500 => ApiException(
          ApiErrorKind.server,
          'Ayuvo had a problem answering. Try again in a moment.',
          statusCode: status,
          detail: detail,
        ),
      final int s when s >= 400 => ApiException(
          ApiErrorKind.invalid,
          detail ?? "The server wouldn't accept that.",
          statusCode: status,
          detail: detail,
        ),
      _ => ApiException(
          ApiErrorKind.unknown,
          "Something failed that shouldn't have. Try again.",
          statusCode: status,
          detail: detail,
        ),
    };
  }

  /// FastAPI answers with `{"detail": "..."}` for an HTTPException and
  /// `{"detail": [{loc, msg, type}, ...]}` for a validation error. Both end up
  /// as one readable line.
  static String? _detailOf(Object? data) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      if (detail is List) {
        final messages = detail
            .whereType<Map>()
            .map((e) => e['msg'])
            .whereType<String>()
            .map(_stripPydanticPrefix)
            .where((m) => m.isNotEmpty)
            .toList();
        if (messages.isNotEmpty) return messages.join('\n');
      }
    }
    return null;
  }

  /// Pydantic v2 prefixes a custom validator's message with "Value error, ".
  static String _stripPydanticPrefix(String message) {
    const prefix = 'Value error, ';
    final cleaned =
        message.startsWith(prefix) ? message.substring(prefix.length) : message;
    return cleaned.trim();
  }

  @override
  String toString() => 'ApiException(${kind.name}, $statusCode): $message';
}
