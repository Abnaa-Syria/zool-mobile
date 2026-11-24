import 'package:zool_core/zool_core.dart';

/// GET /driver/me (also `driver` in the OTP verify response).
class DriverMe {
  DriverMe(this.json);

  final Json json;
  String get id => json.str('id');
  String get driverCode => json.str('driverCode');
  String get displayName => json.str('displayName');
  String get phone => json.str('phone');
  String? get avatarUrl => json.strOrNull('avatarUrl');
  Json get company => json.obj('company');
  String get companyName => company.str('name');
  String get companyLegalName => company.str('legalName');
  String? get companyLogo => company.strOrNull('logoUrl');
  Json get license => json.obj('license');
  String? get licenseNumber => license.strOrNull('number');

  /// `YYYY-MM-DD` calendar date.
  DateTime? get licenseExpiry {
    final s = license.strOrNull('expiry');
    return s == null ? null : DateTime.tryParse(s);
  }

  /// VALID · EXPIRING · EXPIRED.
  String get licenseStatus => license.str('status', 'VALID');
}

/// One stop of a trip (origin, intermediate STOP with an id, destination).
class TripStop {
  TripStop(this.json);

  final Json json;
  String? get id => json.strOrNull('id');
  String get kind => json.str('kind');
  bool get isOrigin => kind == 'ORIGIN';
  bool get isDestination => kind == 'DESTINATION';
  String get cityName => json.obj('city').str('nameAr');
  String get stationName => json.objOrNull('station')?.str('nameAr') ?? '';
  DateTime? get scheduledAt => json.date('scheduledAt');
  DateTime? get arrivedAt => json.date('arrivedAt');
  DateTime? get departedAt => json.date('departedAt');
}

/// Driver trip card / detail (GET /driver/dashboard, /driver/trips, /driver/trips/:id).
class DriverTrip {
  DriverTrip(this.json);

  final Json json;
  String get id => json.str('id');
  String get tripNumber => json.str('tripNumber');

  /// SCHEDULED · BOARDING · IN_PROGRESS · COMPLETED · CANCELLED.
  String get status => json.str('status');
  bool get isLive => status == 'BOARDING' || status == 'IN_PROGRESS';
  String get carrierName => json.obj('carrier').str('name');
  String get serviceClass => json.str('serviceClass');
  DateTime? get departureAt => json.date('departureAt');
  DateTime? get arrivalAt => json.date('arrivalAt');
  int? get durationMinutes => json.intOrNull('durationMinutes');
  String get originCity => json.obj('origin').obj('city').str('nameAr');
  String get destinationCity => json.obj('destination').obj('city').str('nameAr');
  String get originStation => json.obj('origin').objOrNull('station')?.str('nameAr') ?? '';
  String get destinationStation => json.obj('destination').objOrNull('station')?.str('nameAr') ?? '';
  List<TripStop> get stops => json.list('stops').map(TripStop.new).toList();
  List<TripStop> get middleStops => stops.where((s) => s.kind == 'STOP').toList();
  int get stopsCount => json.integer('stopsCount');
  int get seatsTotal => json.integer('seatsTotal');
  String? get vehicleModel => json.objOrNull('vehicle')?.strOrNull('model') ?? json.strOrNull('vehicleModel');
  String? get plateNumber => json.objOrNull('vehicle')?.strOrNull('plateNumber');
  int get booked => json.obj('counts').integer('booked');
  int get boarded => json.obj('counts').integer('boarded');
  int get noShow => json.obj('counts').integer('noShow');
  int get pending => booked - boarded - noShow;
  int get cashExpectedMinor => json.obj('cash').integer('expectedMinor');
  int get cashCollectedMinor => json.obj('cash').integer('collectedMinor');
  List<String> get allowedTransitions => json.strings('allowedTransitions');
  bool can(String status) => allowedTransitions.contains(status);
  DateTime? get startedAt => json.date('startedAt');
  DateTime? get completedAt => json.date('completedAt');

  /// Live tracking view (detail only): position, timeline, progress.
  Json? get live => json.objOrNull('live');
  String get routeLabel => '$originCity ← $destinationCity';

  /// "شندي · البجراوية" or «مباشر».
  String get stopsSummary {
    final names = middleStops.map((s) => s.cityName).where((n) => n.isNotEmpty).toList();
    return names.isEmpty ? 'مباشر' : names.join(' · ');
  }
}

/// GET /driver/dashboard.
class DriverDashboard {
  DriverDashboard(this.json);

  final Json json;
  int get tripsToday => json.obj('kpis').integer('tripsToday');
  int get bookedSeatsToday => json.obj('kpis').integer('bookedSeatsToday');
  int get boardedToday => json.obj('kpis').integer('boardedToday');
  DriverTrip? get currentTrip => json.objOrNull('currentTrip') == null ? null : DriverTrip(json.obj('currentTrip'));
  DriverTrip? get nextTrip => json.objOrNull('nextTrip') == null ? null : DriverTrip(json.obj('nextTrip'));
  List<DriverTrip> get todayTrips => json.list('todayTrips').map(DriverTrip.new).toList();
}

/// One manifest row (a ticket) — also the `ticket` of a scan result.
class ManifestEntry {
  ManifestEntry(this.json);

  final Json json;
  String get ticketNumber => json.str('ticketNumber');
  String get seatLabel => json.str('seatLabel');
  bool get womenOnlySeat => json.flag('isWomenOnlySeat');
  String get fullName => json.obj('passenger').str('fullName');
  String? get phone => json.obj('passenger').strOrNull('phone');
  String get gender => json.obj('passenger').str('gender');
  String get ticketStatus => json.str('ticketStatus');

  /// PENDING · BOARDED · NO_SHOW.
  String get boardingStatus => json.str('boardingStatus', 'PENDING');
  bool get isBoarded => boardingStatus == 'BOARDED';
  bool get isNoShow => boardingStatus == 'NO_SHOW';
  bool get isPending => boardingStatus == 'PENDING';
  String? get boardingMethod => json.strOrNull('boardingMethod');
  DateTime? get boardedAt => json.date('boardedAt');
  String get bookingRef => json.str('bookingRef');
  String get channel => json.str('channel');
  String? get soldBy => json.strOrNull('soldBy');
  String get paymentMethod => json.str('paymentMethod');
  bool get isCash => paymentMethod == 'CASH_ON_BOARD';
  int get fareMinor => json.integer('fareMinor');
  int get cashToCollectMinor => json.integer('cashToCollectMinor');
  int get cashCollectedMinor => json.integer('cashCollectedMinor');
}

/// GET /driver/trips/:id/manifest.
class Manifest {
  Manifest(this.json);

  final Json json;
  String get status => json.str('status');
  int get booked => json.obj('counts').integer('booked');
  int get boarded => json.obj('counts').integer('boarded');
  int get pending => json.obj('counts').integer('pending');
  int get noShow => json.obj('counts').integer('noShow');
  List<ManifestEntry> get passengers => json.list('passengers').map(ManifestEntry.new).toList();
}

/// POST /driver/trips/:id/scan.
class ScanResult {
  ScanResult(this.json);

  final Json json;

  /// VALID · ALREADY_BOARDED · WRONG_TRIP · CANCELLED · INVALID.
  String get result => json.str('result');
  bool get isValid => result == 'VALID';
  ManifestEntry? get ticket => json.objOrNull('ticket') == null ? null : ManifestEntry(json.obj('ticket'));
  Json get trip => json.obj('trip');
  String get tripLabel => '${trip.str('origin')} ← ${trip.str('destination')}';
  DateTime? get departureAt => trip.date('departureAt');
}

/// GET /driver/trips/:id/cash.
class CashSummary {
  CashSummary(this.json);

  final Json json;
  int get expectedMinor => json.integer('expectedMinor');
  int get collectedMinor => json.integer('collectedMinor');
  int get outstandingMinor => json.integer('outstandingMinor');
  List<Json> get tickets => json.list('tickets');
}

class AppNotification {
  AppNotification(this.json);

  final Json json;
  String get id => json.str('id');
  String get type => json.str('type');
  String get title => json.str('title');
  String get body => json.str('body');
  bool get isRead => json.flag('isRead');
  DateTime? get createdAt => json.date('createdAt');
  Json get data => json.obj('data');
}
