/// An API failure. Clients branch on [code] (backend `error-codes.ts`), never on [message].
class ApiException implements Exception {
  ApiException({required this.code, required this.message, this.statusCode, this.details, this.requestId});

  /// No response (offline, DNS, timeout).
  factory ApiException.network([Object? cause]) =>
      ApiException(code: networkError, message: cause?.toString() ?? 'Network error');

  static const String networkError = 'NETWORK_ERROR';

  final String code;
  final String message;
  final int? statusCode;
  final Object? details;
  final String? requestId;

  bool get isNetwork => code == networkError;
  bool get isUnauthorized => statusCode == 401;

  /// `details` as a map (empty when absent or not an object).
  Map<String, dynamic> get detailsMap => details is Map ? Map<String, dynamic>.from(details as Map) : const {};

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}
