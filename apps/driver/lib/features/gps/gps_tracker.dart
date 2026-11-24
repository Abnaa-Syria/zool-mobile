import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zool_core/zool_core.dart';

import '../../data/driver_api.dart';

typedef GpsSender = Future<void> Function(String tripId, List<GpsPoint> points);
typedef GpsLocator = Future<GpsPoint?> Function();

/// Why the tracker cannot read the location.
enum GpsProblem { none, serviceOff, denied, deniedForever }

/// Sends the bus position while a trip is BOARDING / IN_PROGRESS (D-GPS-01).
///
/// Every [interval] it reads one fix, appends it to a buffer kept in shared preferences (so a
/// network gap or an app restart loses nothing) and flushes the buffer in batches of 100. The
/// backend drops fixes older than its window, so an old buffer is harmless.
class GpsTracker extends ChangeNotifier {
  GpsTracker({required this.send, GpsLocator? locate, this.interval = const Duration(seconds: 20), this.enabled = true})
      : _locate = locate ?? _deviceFix;

  final GpsSender send;
  final GpsLocator _locate;
  final Duration interval;

  /// False in widget tests (no platform channels).
  final bool enabled;

  static const _maxBuffer = 500;
  static const _batch = 100;
  static const _keyPrefix = 'zoolgo.driver.gps.';

  String? _tripId;
  Timer? _timer;
  bool _busy = false;
  final List<GpsPoint> _buffer = [];
  DateTime? _lastSentAt;
  GpsPoint? _lastFix;
  GpsProblem _problem = GpsProblem.none;

  String? get tripId => _tripId;
  bool get active => _tripId != null;
  int get pending => _buffer.length;
  DateTime? get lastSentAt => _lastSentAt;
  GpsPoint? get lastFix => _lastFix;
  GpsProblem get problem => _problem;

  /// Starts (or keeps) tracking [tripId]; another trip being tracked is stopped first.
  Future<void> start(String tripId) async {
    if (!enabled || _tripId == tripId) return;
    await stop();
    _tripId = tripId;
    _buffer
      ..clear()
      ..addAll(await _restore(tripId));
    notifyListeners();
    await _ensurePermission();
    unawaited(_tick());
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  /// Stops tracking; pending fixes stay saved and are sent on the next start of that trip.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (_tripId == null) return;
    _tripId = null;
    notifyListeners();
  }

  /// Asks for permission again (from the banner).
  Future<void> retryPermission() async {
    await _ensurePermission(openSettings: true);
    if (_problem == GpsProblem.none) unawaited(_tick());
  }

  Future<void> _ensurePermission({bool openSettings = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _problem = GpsProblem.serviceOff;
        if (openSettings) await Geolocator.openLocationSettings();
      } else {
        var p = await Geolocator.checkPermission();
        if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
        if (p == LocationPermission.deniedForever && openSettings) await Geolocator.openAppSettings();
        _problem = switch (p) {
          LocationPermission.denied => GpsProblem.denied,
          LocationPermission.deniedForever => GpsProblem.deniedForever,
          _ => GpsProblem.none,
        };
      }
    } catch (_) {
      _problem = GpsProblem.denied;
    }
    notifyListeners();
  }

  Future<void> _tick() async {
    final tripId = _tripId;
    if (tripId == null || _busy) return;
    _busy = true;
    try {
      GpsPoint? fix;
      try {
        fix = await _locate();
        if (_problem != GpsProblem.none && fix != null) _problem = GpsProblem.none;
      } catch (_) {
        await _ensurePermission();
      }
      if (fix != null) {
        _lastFix = fix;
        _buffer.add(fix);
        if (_buffer.length > _maxBuffer) _buffer.removeRange(0, _buffer.length - _maxBuffer);
      }
      while (_buffer.isNotEmpty && _tripId == tripId) {
        final chunk = _buffer.take(_batch).toList();
        try {
          await send(tripId, chunk);
        } on ApiException catch (e) {
          // 409: the trip is no longer boarding / in progress — nothing more to send.
          if (e.statusCode == 409) {
            _buffer.clear();
            await _persist(tripId);
            await stop();
            return;
          }
          // 422 (a bad point) would block the queue forever; drop that batch.
          if (e.statusCode == 422) {
            _buffer.removeRange(0, chunk.length);
            continue;
          }
          break;
        } catch (_) {
          break; // offline: keep the buffer for the next tick.
        }
        _buffer.removeRange(0, chunk.length);
        _lastSentAt = DateTime.now();
      }
      await _persist(tripId);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<List<GpsPoint>> _restore(String tripId) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString('$_keyPrefix$tripId');
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map((j) {
        return GpsPoint(
          lat: (j['lat'] as num).toDouble(),
          lng: (j['lng'] as num).toDouble(),
          speedKmh: j['speedKmh'] as int?,
          heading: j['heading'] as int?,
          recordedAt: DateTime.parse(j['recordedAt'] as String),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_buffer.isEmpty) {
        await prefs.remove('$_keyPrefix$tripId');
      } else {
        await prefs.setString('$_keyPrefix$tripId', jsonEncode(_buffer.map((p) => p.toJson()).toList()));
      }
    } catch (_) {}
  }

  static Future<GpsPoint?> _deviceFix() async {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    final speed = p.speed.isFinite && p.speed >= 0 ? (p.speed * 3.6).round().clamp(0, 300) : null;
    final heading = p.heading.isFinite && p.heading >= 0 ? p.heading.round() % 360 : null;
    return GpsPoint(lat: p.latitude, lng: p.longitude, speedKmh: speed, heading: heading, recordedAt: p.timestamp);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
