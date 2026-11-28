import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:zool_core/zool_core.dart';

import 'firebase_config.dart';

// The registration-token API (getToken / onTokenRefresh / deleteToken) is what firebase-admin's
// send() targets; FCM's newer FID registration is not used by the backend yet.
// ignore_for_file: deprecated_member_use

/// A push message as the app sees it: title/body plus the deep-link data (`type`, `bookingId`,
/// `tripId`, … — the same `data` as the in-app notification feed).
class PushNote {
  const PushNote({required this.title, required this.body, required this.data});

  final String title;
  final String body;
  final Map<String, String> data;

  String? get type => data['type'];
}

/// FCM for one app surface: registers this device with the backend (`POST {devicesPath}`) while
/// signed in, drops the FCM token on sign-out (so the old account stops receiving), and reports
/// taps on notifications and messages that arrive while the app is open.
///
/// Android only for now; iOS is added with the Apple setup.
class ZoolPush {
  ZoolPush({required this.app, required this.client, required this.devicesPath});

  final ZoolApp app;
  final ApiClient client;

  /// e.g. `/customer/devices`.
  final String devicesPath;

  bool _ready = false;
  String? _registered;
  StreamSubscription<String>? _refresh;
  PushNote? _pendingTap;
  final _taps = StreamController<PushNote>.broadcast();
  final _foreground = StreamController<PushNote>.broadcast();

  /// Notification tapped while the app was in the background (or a pending launch tap, see [bind]).
  Stream<PushNote> get taps => _taps.stream;

  /// Message received while the app is open (Android shows nothing by itself then).
  Stream<PushNote> get foreground => _foreground.stream;

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!supported) return;
    try {
      await Firebase.initializeApp(options: app.androidOptions);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _taps.add(_note(m)));
      FirebaseMessaging.onMessage.listen((m) => _foreground.add(_note(m)));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingTap = _note(initial);
      _ready = true;
    } catch (e) {
      debugPrint('Push unavailable: $e');
    }
  }

  /// Follows [session]: registers after sign-in, unregisters on sign-out. A notification that
  /// launched the app is delivered on [taps] once the user is signed in.
  void bind(AuthSession session) {
    void sync() {
      if (session.isSignedIn) {
        unawaited(_register());
        final tap = _pendingTap;
        if (tap != null) {
          _pendingTap = null;
          // Let the router settle on the home screen first.
          Future<void>.delayed(const Duration(milliseconds: 600), () => _taps.add(tap));
        }
      } else if (session.status == AuthStatus.signedOut) {
        unawaited(_unregister());
      }
    }

    session.addListener(sync);
    sync();
  }

  Future<void> _register() async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _send(token);
      _refresh ??= messaging.onTokenRefresh.listen((t) => unawaited(_send(t)));
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  Future<void> _send(String token) async {
    if (token == _registered) return;
    try {
      await client.post(devicesPath, body: {'platform': 'ANDROID', 'pushToken': token});
      _registered = token;
    } catch (e) {
      debugPrint('Device registration failed: $e');
    }
  }

  Future<void> _unregister() async {
    await _refresh?.cancel();
    _refresh = null;
    final had = _registered != null;
    _registered = null;
    if (!_ready || !had) return;
    // The session is already gone, so the backend cannot be told; a deleted token makes FCM
    // report it as unregistered and the backend drops it on the next send.
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  static PushNote _note(RemoteMessage m) => PushNote(
        title: m.notification?.title ?? '',
        body: m.notification?.body ?? '',
        data: m.data.map((k, v) => MapEntry(k, '$v')),
      );
}
