/// Small helpers to read the API's JSON without boilerplate. Missing or mistyped values fall back
/// to safe defaults so one unexpected field never crashes a screen.
typedef Json = Map<String, dynamic>;

extension JsonRead on Json {
  String str(String key, [String fallback = '']) {
    final v = this[key];
    return v == null ? fallback : v.toString();
  }

  String? strOrNull(String key) {
    final v = this[key];
    return v?.toString();
  }

  int integer(String key, [int fallback = 0]) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  int? intOrNull(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? numOrNull(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool flag(String key, [bool fallback = false]) {
    final v = this[key];
    return v is bool ? v : fallback;
  }

  Json obj(String key) {
    final v = this[key];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  Json? objOrNull(String key) {
    final v = this[key];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  List<Json> list(String key) {
    final v = this[key];
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<String> strings(String key) {
    final v = this[key];
    if (v is! List) return const [];
    return v.map((e) => e.toString()).toList();
  }

  DateTime? date(String key) {
    final v = this[key];
    return v is String ? DateTime.tryParse(v) : null;
  }
}

/// Casts a decoded JSON value to a list of maps.
List<Json> jsonList(Object? value) =>
    value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

/// Casts a decoded JSON value to a map.
Json jsonObj(Object? value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
