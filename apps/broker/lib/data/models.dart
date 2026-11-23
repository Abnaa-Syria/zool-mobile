import 'package:zool_core/zool_core.dart';

/// Shapes of the broker API (same contract as the broker web panel, D-BROKER-CHANNEL-01).
/// Money fields are integer minor units.

/// GET /broker/auth/me
class BrokerMe {
  BrokerMe(this.json);

  final Json json;

  String get id => json.str('id');
  String get displayName => json.str('displayName');
  String get role => json.str('role');
  bool get isManager => role == 'MANAGER';
  Json get office => json.obj('office');
  String get officeName => office.str('name');
  String get officeCode => office.str('code');
  Set<String> get permissions => json.strings('permissions').toSet();
  String? get phone {
    final ids = json.list('identities');
    final primary = ids.where((i) => i.str('type') == 'PHONE').toList();
    return primary.isEmpty ? null : primary.first.str('value');
  }

  bool get canBook => permissions.contains('broker.book');
  bool get canTopUp => permissions.contains('broker.wallet.topup') || isManager;

  /// The API lets managers read reports and commissions without the explicit flag.
  bool get canViewReports => permissions.contains('broker.reports.view') || isManager;
}

class City {
  City(this.json);

  final Json json;
  String get id => json.str('id');
  String get name => json.str('nameAr');
}

/// `{ station: {nameAr} | null, city: {nameAr} }`
class TripPoint {
  TripPoint(this.json);

  final Json json;
  String get city => json.obj('city').str('nameAr', '—');
  String? get cityId => json.obj('city').strOrNull('id');
  String? get station => json.objOrNull('station')?.strOrNull('nameAr');
}

class TripStop {
  TripStop(this.json);

  final Json json;
  String get kind => json.str('kind');
  String get city => json.obj('city').str('nameAr');
  String? get station => json.objOrNull('station')?.strOrNull('nameAr');
  DateTime? get scheduledAt => json.date('scheduledAt');
}

/// GET /broker/trips item (+ layout/seats on GET /broker/trips/:id).
class BrokerTrip {
  BrokerTrip(this.json);

  final Json json;

  String get id => json.str('id');
  String? get tripNumber => json.strOrNull('tripNumber');
  String get companyName => json.obj('company').str('name');
  String? get legalName => json.obj('carrier').strOrNull('legalName');
  String? get logoUrl => json.obj('carrier').strOrNull('logoUrl');
  int? get ratingCount => json.obj('carrier').obj('rating').intOrNull('count');
  String get serviceClass => json.str('serviceClass', 'STANDARD');
  TripPoint get origin => TripPoint(json.obj('origin'));
  TripPoint get destination => TripPoint(json.obj('destination'));
  DateTime? get departureAt => json.date('departureAt');
  DateTime? get arrivalAt => json.date('arrivalAt');
  int? get durationMinutes => json.intOrNull('durationMinutes');
  bool get isDirect => json.flag('isDirect', true);
  List<TripStop> get stops => json.list('stops').map(TripStop.new).toList();
  List<Json> get amenities => json.list('amenities');
  String? get vehicleModel => json.strOrNull('vehicleModel');
  int get basePrice => json.integer('basePrice');
  double get commissionPercent => json.numOrNull('commissionPercent') ?? 0;
  int get expectedCommissionPerSeat => json.integer('expectedCommissionPerSeat');
  int get seatsFree => json.integer('seatsFree');
  int get seatsTotal => json.integer('seatsTotal');
  double? get rating => json.obj('carrier').obj('rating').numOrNull('average');

  int get intermediateStops => stops.where((s) => s.kind == 'STOP').length;

  Json? get layout => json.objOrNull('layout');
  List<TripSeat> get seats => json.list('seats').map(TripSeat.new).toList();
}

class TripSeat {
  TripSeat(this.json);

  final Json json;
  String get id => json.str('id');
  String get label => json.str('label');
  String get status => json.str('status');
  bool get heldByMe => json.flag('heldByMe');
  String? get holdId => json.strOrNull('holdId');
  int? get row => json.intOrNull('row');
  int? get column => json.intOrNull('column');
  bool get womenOnly => json.flag('isWomenOnly');
  bool get available => status == 'FREE' || heldByMe;
}

/// POST /broker/trips/:id/holds
class HoldResult {
  HoldResult(this.json);

  final Json json;
  DateTime get expiresAt => json.date('expiresAt') ?? DateTime.now().add(const Duration(minutes: 5));
  List<Json> get holds => json.list('holds');
  List<String> get holdIds => holds.map((h) => h.str('id')).toList();
}

class BookingTicket {
  BookingTicket(this.json);

  final Json json;
  String get ticketNumber => json.str('ticketNumber');
  String get status => json.str('status');
  String get seatLabel => json.str('seatLabel', '—');
  String get passengerName => json.str('passengerName', '—');
  String get boardingStatus => json.str('boardingStatus', 'PENDING');
  String? get qrPayload => json.strOrNull('qrPayload');
  bool get active => status != 'CANCELLED';
}

class Passenger {
  Passenger(this.json);

  final Json json;
  String get fullName => json.str('fullName');
  String? get phone => json.strOrNull('phone');
  String? get idNumber => json.strOrNull('idNumber');
  String? get gender => json.strOrNull('gender');
}

/// Booking DTO (GET /broker/bookings, /broker/bookings/:id).
class Booking {
  Booking(this.json);

  final Json json;

  String get id => json.str('id');
  String get status => json.str('status');
  String get reference => json.strOrNull('bookingRef') ?? id.substring(0, id.length < 8 ? id.length : 8).toUpperCase();
  Json get trip => json.obj('trip');
  String get tripId => trip.str('id');
  String get origin => trip.str('origin');
  String get destination => trip.str('destination');
  DateTime? get departureAt => trip.date('departureAt');
  String get companyName => trip.obj('company').str('name');
  int get totalMinor => json.integer('totalAmountMinor');
  int get commissionMinor => json.integer('commissionAmountMinor');
  String? get commissionStatus => json.strOrNull('commissionStatus');
  String? get employeeName => json.objOrNull('employee')?.strOrNull('displayName');
  DateTime? get createdAt => json.date('createdAt');
  DateTime? get cancelledAt => json.date('cancelledAt');
  String? get leg => json.strOrNull('leg');
  String? get groupId => json.strOrNull('groupId');
  String? get replacedByBookingId => json.strOrNull('replacedByBookingId');
  String? get replacesBookingId => json.strOrNull('replacesBookingId');
  int get changeCount => json.integer('changeCount');
  List<Passenger> get passengers => json.list('passengers').map(Passenger.new).toList();
  List<BookingTicket> get tickets => json.list('tickets').map(BookingTicket.new).toList();
  List<BookingTicket> get activeTickets => tickets.where((t) => t.active).toList();

  bool get isConfirmed => status == 'CONFIRMED';
  bool get departed => departureAt != null && departureAt!.isBefore(DateTime.now());

  /// Cancel / change: confirmed bookings before departure (the API enforces cut-offs too).
  bool get canModify => isConfirmed && !departed;
}

/// POST /broker/bookings/quote
class BookingQuote {
  BookingQuote(this.json);

  final Json json;
  int get seatCount => json.integer('seatCount');
  int get unitPriceMinor => json.integer('unitPriceMinor');
  int get totalMinor => json.integer('totalAmountMinor');
  int get commissionMinor => json.integer('expectedCommissionMinor');
  double get commissionPercent => json.numOrNull('commissionPercent') ?? 0;
  int get walletBalanceMinor => json.integer('walletBalanceMinor');
  int get balanceAfterMinor => json.integer('balanceAfterMinor');
  bool get sufficientBalance => json.flag('sufficientBalance', true);
  Json get exposure => json.obj('exposure');
  BookingQuote? get returnLeg => json.objOrNull('returnLeg') == null ? null : BookingQuote(json.obj('returnLeg'));

  /// Wallet debit: both legs for a round trip.
  int get grandTotalMinor => json.intOrNull('combinedTotalMinor') ?? totalMinor;
  int get grandCommissionMinor => json.intOrNull('combinedCommissionMinor') ?? commissionMinor;

  /// Confirm counts the tickets of BOTH legs against the daily ceiling.
  bool get withinCeiling {
    final tickets = seatCount + (returnLeg?.seatCount ?? 0);
    return exposure.integer('usedToday') + tickets <= exposure.integer('ceiling', 1 << 30);
  }
}

/// GET /broker/bookings/:id/change-options item.
class ChangeOption {
  ChangeOption(this.json);

  final Json json;
  String get id => json.str('id');
  DateTime? get departureAt => json.date('departureAt');
  DateTime? get arrivalAt => json.date('arrivalAt');
  int? get durationMinutes => json.intOrNull('durationMinutes');
  TripPoint get origin => TripPoint(json.obj('origin'));
  TripPoint get destination => TripPoint(json.obj('destination'));
  int get seatsAvailable => json.integer('seatsAvailable');
  int get priceMinor => json.integer('priceMinor');
  int get priceDifferenceMinor => json.integer('priceDifferenceMinor');
  String get carrierName => json.obj('carrier').str('name');
}

/// GET /broker/wallet/ledger item.
class LedgerEntry {
  LedgerEntry(this.json);

  final Json json;
  String get id => json.str('id');
  String get type => json.str('type');
  bool get credit => json.str('direction') == 'CREDIT';
  int get amountMinor => json.integer('amountMinor');
  int get balanceAfterMinor => json.integer('balanceAfterMinor');
  String? get referenceType => json.strOrNull('referenceType');
  String? get referenceId => json.strOrNull('referenceId');
  DateTime? get createdAt => json.date('createdAt');
}

/// Top-up intent.
class TopUp {
  TopUp(this.json);

  final Json json;
  String get id => json.str('id');
  int get amountMinor => json.integer('amountMinor');
  String get status => json.str('status');
  bool get hasEvidence => json.flag('hasEvidence');
  String? get note => json.strOrNull('note');
  String? get paymentReference => json.strOrNull('paymentReferenceNormalized');
  DateTime? get createdAt => json.date('createdAt');
  DateTime? get confirmedAt => json.date('confirmedAt');
  DateTime? get failedAt => json.date('failedAt');
  bool get mockConfirmAvailable => json.flag('mockConfirmAvailable');
  bool get open => status == 'PENDING' || status == 'PENDING_REVIEW';
}

class AppNotification {
  AppNotification(this.json);

  final Json json;
  String get id => json.str('id');
  String get title => json.str('title');
  String get body => json.str('body');
  bool get isRead => json.flag('isRead');
  DateTime? get createdAt => json.date('createdAt');
  Json get data => json.obj('data');
}

class CommissionAccrual {
  CommissionAccrual(this.json);

  final Json json;
  String get id => json.str('id');
  String get bookingId => json.str('bookingId');
  int get amountMinor => json.integer('amountMinor');
  String get status => json.str('status');
  int get bookingTotalMinor => json.obj('booking').integer('totalAmountMinor');
  DateTime? get createdAt => json.date('createdAt');
}
