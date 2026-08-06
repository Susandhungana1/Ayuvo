/// The single HTTP client. Repositories call it; widgets never do.
///
/// It owns three things no caller should have to remember:
///   1. the bearer token goes on every authenticated request,
///   2. a 401 on an authenticated request ends the session exactly once,
///   3. every failure leaves here as an [ApiException], never a [DioException].
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exception.dart';

/// Marks a request that carries no session — sign-in, register, forgot/reset
/// password, `/health`. A 401 on one of these means "those credentials are
/// wrong", not "your session is over", and must not sign anyone out.
const _unauthenticatedKey = 'medistore.unauthenticated';

/// Options for a route that runs without a session.
final Options unauthenticated = Options(extra: {_unauthenticatedKey: true});

class ApiClient {
  ApiClient({required String baseUrl, Dio? dio})
      : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl,
      // A phone on a bad connection should fail in seconds and offer Retry,
      // not spin for a minute.
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      // Never let dio throw on a status by itself — the error interceptor below
      // is the only place a response becomes an exception.
      headers: {'Accept': 'application/json'},
    );
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _attachToken, onError: _translate),
    );
  }

  final Dio _dio;

  String? _token;

  /// Called once, by the session controller, when a 401 proves the session is
  /// dead. Kept as a callback rather than a provider read so the client has no
  /// dependency on the session — the session depends on it.
  VoidCallback? onSessionExpired;

  String get baseUrl => _dio.options.baseUrl;

  /// The session controller sets this on sign-in and clears it on sign-out.
  // ignore: use_setters_to_change_properties — reads better at the call site.
  void useToken(String? token) => _token = token;

  void _attachToken(RequestOptions options, RequestInterceptorHandler handler) {
    final isPublic = options.extra[_unauthenticatedKey] == true;
    if (!isPublic && _token != null) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    handler.next(options);
  }

  void _translate(DioException error, ErrorInterceptorHandler handler) {
    final isPublic = error.requestOptions.extra[_unauthenticatedKey] == true;
    var failure = ApiException.from(error);

    // A 401 anywhere else means the seven-day token has expired or been
    // revoked. There is no refresh token, so the only correct answer is to end
    // the session and route to sign-in with a reason.
    if (!isPublic && error.response?.statusCode == 401) {
      failure = const ApiException(
        ApiErrorKind.unauthorized,
        'Your session has ended. Sign in again.',
        statusCode: 401,
      );
      onSessionExpired?.call();
    }

    handler.reject(
      DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        type: error.type,
        error: failure,
      ),
    );
  }

  Future<T> get<T>(String path, {Options? options}) =>
      _send(() => _dio.get<T>(path, options: options));

  Future<T> post<T>(String path, {Object? body, Options? options}) =>
      _send(() => _dio.post<T>(path, data: body, options: options));

  Future<T> put<T>(String path, {Object? body, Options? options}) =>
      _send(() => _dio.put<T>(path, data: body, options: options));

  Future<T> patch<T>(String path, {Object? body, Options? options}) =>
      _send(() => _dio.patch<T>(path, data: body, options: options));

  Future<T> delete<T>(String path, {Object? body, Options? options}) =>
      _send(() => _dio.delete<T>(path, data: body, options: options));

  /// Form-encoded POST. Only `/api/auth/login` needs it: FastAPI's
  /// `OAuth2PasswordRequestForm` reads `username`/`password` from a form body,
  /// and `OAuth2PasswordBearer(tokenUrl=...)` pins that shape in place.
  Future<T> postForm<T>(String path, Map<String, String> fields) => _send(
        () => _dio.post<T>(
          path,
          data: fields,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            extra: {_unauthenticatedKey: true},
          ),
        ),
      );

  Future<T> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } on DioException catch (error, stack) {
      // The interceptor already translated it; unwrap rather than re-derive.
      final inner = error.error;
      throw inner is ApiException ? inner : ApiException.from(error, stack);
    }
  }

  void close() => _dio.close(force: true);
}
