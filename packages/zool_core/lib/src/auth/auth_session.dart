import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/json.dart';
import 'token_store.dart';

enum AuthStatus { unknown, signedIn, signedOut }

/// OTP login + rotating refresh tokens for one app surface (`/broker/auth`, `/customer/auth`,
/// `/driver/auth`). The access token lives in memory only; the refresh token in [TokenStore].
///
/// Rotation (API_CONVENTIONS §2): every refresh returns a NEW refresh token that replaces the old
/// one, and concurrent refreshes share one request — reusing an old token revokes the family.
class AuthSession extends ChangeNotifier {
  AuthSession({required this.authPath, required this.store, Dio? dio}) : _dio = dio ?? createDio();

  /// e.g. `/broker/auth`.
  final String authPath;
  final TokenStore store;
  final Dio _dio;

  AuthStatus _status = AuthStatus.unknown;
  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshing;

  /// Data of the last verify/refresh response (the mobile engine includes the profile there).
  Json lastAuthData = const {};

  AuthStatus get status => _status;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  String? get accessToken => _accessToken;
  bool get canRefresh => _refreshToken != null;

  /// On launch: resumes the session from the stored refresh token.
  Future<void> restore() async {
    _refreshToken = await store.read();
    if (_refreshToken == null) return _set(AuthStatus.signedOut);
    final ok = await refresh();
    // Offline launch: keep the stored session; the first request refreshes once the network is back.
    if (!ok && _refreshToken != null) return _set(AuthStatus.signedIn);
    _set(ok ? AuthStatus.signedIn : AuthStatus.signedOut);
  }

  /// `POST {authPath}/otp/request` → `{ challengeId, expiresAt, cooldownSeconds, devOtp? }`.
  Future<Json> requestOtp(String phone) => _post('/otp/request', {'phone': phone});

  /// `POST {authPath}/otp/verify` → tokens (+ profile for customer/driver). Signs in.
  Future<Json> verifyOtp({required String phone, required String code, String? challengeId}) async {
    final data = await _post('/otp/verify', {
      'phone': phone,
      'code': code,
      'challengeId': ?challengeId,
    });
    await _accept(data);
    _set(AuthStatus.signedIn);
    return data;
  }

  /// Refreshes the access token once for all concurrent callers. Returns false when the session
  /// is gone (expired, revoked, reused) — then the stored token is cleared. A network failure keeps
  /// the stored token and returns false.
  Future<bool> refresh() {
    final pending = _refreshing;
    if (pending != null) return pending;
    final future = _doRefresh();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final token = _refreshToken;
    if (token == null) return false;
    try {
      final data = await _post('/refresh', {'refreshToken': token});
      await _accept(data);
      return true;
    } on ApiException catch (e) {
      if (e.isNetwork) return false;
      await _clear();
      return false;
    }
  }

  /// Ends the session on the server (best effort) and locally.
  Future<void> logout() async {
    final token = _refreshToken;
    if (token != null) {
      try {
        await _post('/logout', {'refreshToken': token});
      } catch (_) {}
    }
    await _clear();
    _set(AuthStatus.signedOut);
  }

  /// Called by [ApiClient] when a request stays unauthorized after refreshing.
  void expire() {
    _clear();
    _set(AuthStatus.signedOut);
  }

  Future<void> _accept(Json data) async {
    lastAuthData = data;
    _accessToken = data.strOrNull('accessToken');
    final next = data.strOrNull('refreshToken');
    if (next != null) {
      _refreshToken = next;
      await store.write(next);
    }
  }

  Future<void> _clear() async {
    _accessToken = null;
    _refreshToken = null;
    lastAuthData = const {};
    await store.clear();
  }

  void _set(AuthStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  Future<Json> _post(String path, Json body) async {
    try {
      final res = await _dio.post<Object?>('$authPath$path', data: body);
      return jsonObj(jsonObj(res.data)['data']);
    } catch (e) {
      throw toApiException(e);
    }
  }
}
