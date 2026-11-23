import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_session.dart';
import '../config.dart';
import 'api_exception.dart';
import 'json.dart';

/// One successful API envelope: `{ success, statusCode, message, data, meta }`.
class ApiResponse {
  const ApiResponse(this.data, this.meta);

  final Object? data;
  final Json? meta;

  Json get json => jsonObj(data);
  List<Json> get items => jsonList(data);

  /// List pagination (`meta: { page, pageSize, total, totalPages }`).
  int get totalPages => meta?.integer('totalPages', 1) ?? 1;
  int get total => meta?.integer('total', items.length) ?? items.length;
}

/// `X-Client-Platform` value (API_CONVENTIONS §2): mobile clients get the refresh token in the body.
String clientPlatformHeader() => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

/// Builds the bare Dio used by [ApiClient] and [AuthSession].
Dio createDio({String? baseUrl}) => Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ZoolConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 60),
        headers: {'X-Client-Platform': clientPlatformHeader(), 'Accept': 'application/json'},
      ),
    );

/// Converts any Dio failure into an [ApiException] carrying the backend error envelope.
ApiException toApiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    final res = error.response;
    if (res == null) return ApiException.network(error.message ?? error.type.name);
    final body = jsonObj(res.data);
    return ApiException(
      code: body.str('code', res.statusCode == 401 ? 'UNAUTHORIZED' : 'HTTP_${res.statusCode}'),
      message: body.str('message', res.statusMessage ?? 'Request failed'),
      statusCode: res.statusCode,
      details: body['details'],
      requestId: body.strOrNull('requestId'),
    );
  }
  return ApiException(code: 'UNEXPECTED', message: error.toString());
}

/// Authenticated API access for one app. On a 401 it refreshes the session once (shared by all
/// concurrent requests) and replays the request; when refreshing fails the session ends.
class ApiClient {
  ApiClient(this.session, {Dio? dio}) : _dio = dio ?? createDio();

  final AuthSession session;
  final Dio _dio;

  Future<ApiResponse> get(String path, {Map<String, Object?>? query}) => _send('GET', path, query: query);

  Future<ApiResponse> post(String path, {Object? body, Map<String, String>? headers}) =>
      _send('POST', path, body: body ?? const <String, Object?>{}, headers: headers);

  Future<ApiResponse> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Future<ApiResponse> delete(String path, {Object? body}) => _send('DELETE', path, body: body);

  Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    bool canRefresh = true,
  }) async {
    final token = session.accessToken;
    try {
      final res = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: _cleanQuery(query),
        options: Options(method: method, headers: {
          ...?headers,
          if (token != null) 'Authorization': 'Bearer $token',
        }),
      );
      final envelope = jsonObj(res.data);
      return ApiResponse(envelope['data'], envelope.objOrNull('meta'));
    } catch (e) {
      final error = toApiException(e);
      if (error.isUnauthorized && canRefresh && session.canRefresh) {
        if (await session.refresh()) {
          return _send(method, path, query: query, body: body, headers: headers, canRefresh: false);
        }
      }
      if (error.isUnauthorized && session.isSignedIn) session.expire();
      throw error;
    }
  }

  static Map<String, Object?>? _cleanQuery(Map<String, Object?>? query) {
    if (query == null) return null;
    final out = <String, Object?>{};
    query.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      out[k] = v;
    });
    return out;
  }
}
