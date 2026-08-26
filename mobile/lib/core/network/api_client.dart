/// The single HTTP client. Repositories call it; widgets never do.
///
/// It owns three things no caller should have to remember:
///   1. the bearer token goes on every authenticated request,
///   2. a 401 on an authenticated request ends the session exactly once,
///   3. every failure leaves here as an [ApiException], never a [DioException].
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exception.dart';

/// Marks a request that carries no session — sign-in, register, forgot/reset
/// password, `/health`. A 401 on one of these means "those credentials are
/// wrong", not "your session is over", and must not sign anyone out.
const _unauthenticatedKey = 'ayuvo.unauthenticated';

/// Options for a route that runs without a session.
final Options unauthenticated = Options(extra: {_unauthenticatedKey: true});

class ApiClient {
  ApiClient({required String baseUrl, Dio? dio})
      : _dio = dio ?? Dio(),
        _refreshDio = Dio() {
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

    // A bare client for `/api/auth/refresh` only. dio serializes its
    // interceptor pipeline per instance, so a refresh issued from inside a
    // pipeline (a 401 handler) can deadlock the very instance it is trying to
    // reach — giving the refresh its own instance with no interceptors and
    // no lock state keeps that path always clear. Same adapter, same timeouts.
    _refreshDio.options = _refreshDio.options.copyWith(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    );
    _refreshDio.httpClientAdapter = _dio.httpClientAdapter;
  }

  final Dio _dio;
  final Dio _refreshDio;

  String? _token;
  String? _refreshToken;

  /// Single-flight guard: several requests can hit 401 at once, but only one
  /// refresh must leave this client. The others await the same future.
  Future<bool>? _refreshInFlight;

  /// Called once, by the session controller, when a 401 proves the session is
  /// dead. Kept as a callback rather than a provider read so the client has no
  /// dependency on the session — the session depends on it.
  VoidCallback? onSessionExpired;

  /// Called after a successful refresh so the session controller can persist
  /// the new pair to the keystore. Same reasoning as [onSessionExpired]. Awaited
  /// so the retried request only fires once the new pair is durable.
  Future<void> Function(String accessToken, String refreshToken)?
      onTokensRefreshed;

  String get baseUrl => _dio.options.baseUrl;

  /// The session controller sets this on sign-in and clears it on sign-out.
  // ignore: use_setters_to_change_properties — reads better at the call site.
  void useToken(String? token) => _token = token;

  /// The current access token, or null when nobody is signed in.
  String? get accessToken => _token;

  /// The current refresh token, or null when nobody is signed in.
  String? get currentRefreshToken => _refreshToken;

  /// Renews the session now, outside any request. Used by the session
  /// controller at launch when the stored access token is already expired —
  /// better to pay one refresh up front than have the first screen load 401.
  Future<bool> refreshNow() => _tryRefresh();

  /// The refresh token lives here too: the 401 interceptor needs it without
  /// having to read storage, and the session controller owns both.
  // ignore: use_setters_to_change_properties
  void useRefreshToken(String? refreshToken) => _refreshToken = refreshToken;

  /// Sign-in/out in one call — keeps both credentials in step.
  void useSession(String? token, String? refreshToken) {
    _token = token;
    _refreshToken = refreshToken;
  }

  void _attachToken(RequestOptions options, RequestInterceptorHandler handler) {
    final isPublic = options.extra[_unauthenticatedKey] == true;
    if (!isPublic && _token != null) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    handler.next(options);
  }

  /// Tries to renew the session exactly once. Success swaps in the new pair and
  /// tells the session controller; failure leaves everything as it was.
  Future<bool> _tryRefresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final attempt = _doRefresh();
    _refreshInFlight = attempt;
    attempt.whenComplete(() => _refreshInFlight = null);
    return attempt;
  }

  Future<bool> _doRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refresh_token': refreshToken},
      ).timeout(const Duration(seconds: 30));
      final data = response.data;
      if (data == null) return false;
      _token = data['token'] as String;
      _refreshToken = data['refresh_token'] as String;
      await onTokensRefreshed?.call(_token!, _refreshToken!);
      return true;
    } on DioException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  void _translate(DioException error, ErrorInterceptorHandler handler) {
    final isPublic = error.requestOptions.extra[_unauthenticatedKey] == true;
    var failure = ApiException.from(error);

    // A 401 on an authenticated route means "the session is over" — but that
    // decision (refresh, or sign out) lives in _send, where dio's interceptor
    // lock is free. Here we only make sure the failure reads like a session
    // problem rather than like bad sign-in credentials.
    if (!isPublic && error.response?.statusCode == 401) {
      failure = const ApiException(
        ApiErrorKind.unauthorized,
        'Your session has ended. Sign in again.',
        statusCode: 401,
      );
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

  /// Fetches an auth-gated binary — a report file, a document attachment.
  ///
  /// These are not public URLs: `Image.network` on one of them sends no bearer
  /// and gets a 401, which is why every image in this app is bytes we fetched
  /// ourselves and handed to `Image.memory`.
  Future<Uint8List> getBytes(String path) => _send<Uint8List>(
        () => _dio.get<Uint8List>(
          path,
          options: Options(
            responseType: ResponseType.bytes,
            // The bytes are the payload; a JSON Accept header on a PDF is a lie.
            headers: {'Accept': '*/*'},
          ),
        ),
      );

  /// Multipart upload with progress.
  ///
  /// [receiveTimeout] is an argument because report upload is the slowest call
  /// in the product — the server runs OCR and then two LLM calls, each with its
  /// own 60-second timeout, before it answers. The default 30 seconds would
  /// abandon a request the server is still working on, and the user would have
  /// no idea their report was in fact saved.
  Future<T> postMultipart<T>(
    String path,
    FormData form, {
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) =>
      _send(
        () => _dio.post<T>(
          path,
          data: form,
          onSendProgress: onSendProgress,
          options: Options(
            receiveTimeout: receiveTimeout,
            sendTimeout: receiveTimeout,
          ),
        ),
      );

  Future<T> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } on DioException catch (error, stack) {
      var failure = error.error is ApiException
          ? error.error as ApiException
          : ApiException.from(error, stack);

      // A 401 on an authenticated call means the access token has expired or
      // been revoked. With a refresh token we renew silently and retry once;
      // without one, the only correct answer is to end the session. This runs
      // here, not in the error interceptor: the interceptor holds dio's
      // request lock, and a nested request made while it is held deadlocks.
      final isPublic = error.requestOptions.extra[_unauthenticatedKey] == true;
      final isAuth401 = !isPublic && error.response?.statusCode == 401;

      if (isAuth401 && _refreshToken != null && await _tryRefresh()) {
        try {
          final response = await request();
          return response.data as T;
        } on DioException catch (retryError, retryStack) {
          // The retried request failed for another reason (offline, 403, ...);
          // report that failure instead.
          failure = retryError.error is ApiException
              ? retryError.error as ApiException
              : ApiException.from(retryError, retryStack);
        }
      } else if (isAuth401) {
        failure = const ApiException(
          ApiErrorKind.unauthorized,
          'Your session has ended. Sign in again.',
          statusCode: 401,
        );
        onSessionExpired?.call();
      }
      throw failure;
    }
  }

  void close() => _dio.close(force: true);
}
