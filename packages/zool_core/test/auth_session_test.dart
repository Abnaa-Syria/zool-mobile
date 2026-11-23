import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zool_core/zool_core.dart';

/// Fake backend: OTP verify, rotating refresh, one protected endpoint.
class FakeBackend implements HttpClientAdapter {
  int refreshCalls = 0;
  int generation = 0;
  String validAccess = 'access-0';
  String validRefresh = 'refresh-0';
  bool refreshRejects = false;
  final List<String> platformHeaders = [];

  ResponseBody _json(int status, Object body) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  Map<String, dynamic> _tokens() {
    generation++;
    validAccess = 'access-$generation';
    validRefresh = 'refresh-$generation';
    return {'accessToken': validAccess, 'refreshToken': validRefresh, 'expiresIn': 900};
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    platformHeaders.add('${options.headers['X-Client-Platform']}');
    final path = options.path;
    final body = options.data is Map ? options.data as Map : const {};
    if (path.endsWith('/otp/verify')) {
      return _json(200, {'success': true, 'data': _tokens()});
    }
    if (path.endsWith('/refresh')) {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (refreshRejects || body['refreshToken'] != validRefresh) {
        return _json(401, {'success': false, 'code': 'TOKEN_REUSE_DETECTED', 'message': 'reuse'});
      }
      return _json(200, {'success': true, 'data': _tokens()});
    }
    if (path.endsWith('/logout')) return _json(200, {'success': true, 'data': {'loggedOut': true}});
    if (path == '/protected') {
      final auth = options.headers['Authorization'];
      if (auth != 'Bearer $validAccess') {
        return _json(401, {'success': false, 'code': 'AUTH_TOKEN_EXPIRED', 'message': 'expired'});
      }
      return _json(200, {'success': true, 'data': {'ok': true}, 'meta': {'page': 1, 'totalPages': 3}});
    }
    if (path == '/conflict') {
      return _json(409, {'success': false, 'code': 'INSUFFICIENT_BALANCE', 'message': 'no money', 'details': {'needed': 5}});
    }
    return _json(404, {'success': false, 'code': 'ROUTE_NOT_FOUND', 'message': 'nope'});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeBackend backend;
  late MemoryTokenStore store;
  late AuthSession session;
  late ApiClient client;

  Dio dio() => createDio(baseUrl: 'http://test')..httpClientAdapter = backend;

  setUp(() {
    backend = FakeBackend();
    store = MemoryTokenStore();
    session = AuthSession(authPath: '/broker/auth', store: store, dio: dio());
    client = ApiClient(session, dio: dio());
  });

  test('verify signs in, stores the refresh token and sends the mobile platform header', () async {
    await session.verifyOtp(phone: '+249900000101', code: '123456', challengeId: 'c1');
    expect(session.status, AuthStatus.signedIn);
    expect(store.value, 'refresh-1');
    final res = await client.get('/protected');
    expect(res.json['ok'], true);
    expect(res.totalPages, 3);
    expect(backend.platformHeaders.every((h) => h == 'android' || h == 'ios'), isTrue);
  });

  test('expired access token: one shared refresh for concurrent requests, then replay', () async {
    await session.verifyOtp(phone: '+249900000101', code: '123456');
    backend.validAccess = 'rotated-on-server'; // current access token no longer valid
    final results = await Future.wait([client.get('/protected'), client.get('/protected'), client.get('/protected')]);
    expect(results.every((r) => r.json['ok'] == true), isTrue);
    expect(backend.refreshCalls, 1);
    expect(store.value, 'refresh-2'); // rotated token stored
  });

  test('restore resumes from the stored refresh token', () async {
    store.value = 'refresh-0';
    await session.restore();
    expect(session.status, AuthStatus.signedIn);
    expect(session.accessToken, 'access-1');
  });

  test('restore without a token is signed out', () async {
    await session.restore();
    expect(session.status, AuthStatus.signedOut);
  });

  test('a rejected refresh ends the session and clears storage', () async {
    await session.verifyOtp(phone: '+249900000101', code: '123456');
    backend.validAccess = 'other';
    backend.refreshRejects = true;
    await expectLater(client.get('/protected'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    expect(session.status, AuthStatus.signedOut);
    expect(store.value, isNull);
  });

  test('error envelopes become ApiException with code and details', () async {
    await session.verifyOtp(phone: '+249900000101', code: '123456');
    await expectLater(
      client.post('/conflict'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INSUFFICIENT_BALANCE').having((e) => e.detailsMap['needed'], 'details', 5)),
    );
  });

  test('logout clears the session', () async {
    await session.verifyOtp(phone: '+249900000101', code: '123456');
    await session.logout();
    expect(session.status, AuthStatus.signedOut);
    expect(store.value, isNull);
    expect(session.accessToken, isNull);
  });
}
