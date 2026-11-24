import 'package:zool_core/zool_core.dart';

/// Shapes of the customer API (`/customer/*`, `/public/*`). Money is integer minor units.

/// GET /customer/me
class CustomerMe {
  CustomerMe(this.json);

  final Json json;
  String get id => json.str('id');
  String? get displayName => json.strOrNull('displayName');
  String get name => displayName ?? 'مسافر زول قو';
  String get phone => json.str('phone');
  String? get email => json.strOrNull('email');
  bool get profileIncomplete => json.flag('profileIncomplete') || displayName == null;
  bool get tripAlerts => json.obj('preferences').flag('tripAlerts', true);
  Json get cash => json.obj('cash');
  int get tripsCount => json.obj('stats').integer('tripsCount');
  int get destinationsCount => json.obj('stats').integer('destinationsCount');
}

/// `{ station: {nameAr} | null, city: {nameAr} }`
class Point {
  Point(this.json);

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

/// Trip card (`GET /customer/trips`) and detail (`GET /customer/trips/:id`).
class Trip {
  Trip(this.json);

  final Json json;
  String get id => json.str('id');
  String? get tripNumber => json.strOrNull('tripNumber');
  String get status => json.str('status');
  Json get carrier => json.obj('carrier');
  String get carrierName => carrier.str('name');
  String? get legalName => carrier.strOrNull('legalName');
  String? get logoUrl => carrier.strOrNull('logoUrl');
  double? get rating => carrier.obj('rating').numOrNull('average');
  int get ratingCount => carrier.obj('rating').integer('count');
  String get serviceClass => json.str('serviceClass', 'STANDARD');
  DateTime? get departureAt => json.date('departureAt');
  DateTime? get arrivalAt => json.date('arrivalAt');
  int? get durationMinutes => json.intOrNull('durationMinutes');
  Point get origin => Point(json.obj('origin'));
  Point get destination => Point(json.obj('destination'));
  int get stopsCount => json.integer('stopsCount');
  int get seatsAvailable => json.integer('seatsAvailable');
  int get priceMinor => json.integer('priceMinor');
  String? get vehicleModel => json.strOrNull('vehicleModel');
  bool get cashAvailable => json.flag('cashAvailable', true);
  List<TripStop> get stops => json.list('stops').map(TripStop.new).toList();

  /// Codes on the card; objects `{code,nameAr,value}` on the detail.
  List<Json> get amenities {
    final raw = json['amenities'];
    if (raw is! List) return const [];
    return raw.map((a) => a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{'code': '$a', 'nameAr': '$a'}).toList();
  }

  String get middleLabel => stopsCount == 0 ? 'مباشر' : '$stopsCount توقف';
}

/// GET /customer/trips/:id/seats seat.
class Seat {
  Seat(this.json);

  final Json json;
  String get id => json.str('id');
  String get label => json.str('label');
  int? get row => json.intOrNull('row');
  int? get column => json.intOrNull('column');
  bool get womenOnly => json.flag('isWomenOnly');
  String get state => json.str('state');
  bool get heldByMe => json.flag('heldByMe');
  bool get available => state == 'AVAILABLE' || heldByMe;
}

class SeatMapData {
  SeatMapData(this.json);

  final Json json;
  Json? get layout => json.objOrNull('layout');
  List<Seat> get seats => json.list('seats').map(Seat.new).toList();
}

/// POST /customer/trips/:id/holds → one hold per seat.
class Hold {
  Hold(this.json);

  final Json json;
  DateTime get expiresAt => json.date('expiresAt') ?? DateTime.now().add(const Duration(minutes: 15));
  List<String> get holdIds => json.list('holds').map((h) => h.str('id')).toList();
}

/// POST /customer/bookings/quote
class Quote {
  Quote(this.json);

  final Json json;
  List<Json> get legs => json.list('legs');
  int get subtotalMinor => json.integer('subtotalMinor');
  int get discountMinor => json.integer('discountMinor');
  int get totalMinor => json.integer('totalMinor');
  Json? get coupon => json.objOrNull('coupon');
  bool get cashAllowed => json.flag('cashAllowed');
  String? get cashBlockedReason => json.strOrNull('cashBlockedReason');
  int get seatCount => legs.fold(0, (n, l) => n + l.list('seats').length);
}

class Ticket {
  Ticket(this.json);

  final Json json;
  String get ticketNumber => json.str('ticketNumber');
  String get status => json.str('status');
  String get boardingStatus => json.str('boardingStatus', 'PENDING');
  String get seatLabel => json.str('seatLabel', '—');
  bool get womenOnlySeat => json.flag('isWomenOnlySeat');
  String get passengerName => json.obj('passenger').str('fullName', '—');
  String? get gender => json.obj('passenger').strOrNull('gender');
  int get fareMinor => json.integer('fareMinor');
  int get cashToCollectMinor => json.integer('cashToCollectMinor');
  String? get qrPayload => json.strOrNull('qrPayload');
  bool get active => status != 'CANCELLED';
}

/// Booking DTO (GET /customer/bookings[/:id]).
class Booking {
  Booking(this.json);

  final Json json;
  String get id => json.str('id');
  String get reference => json.str('bookingRef', id);
  String get status => json.str('status');
  bool get tripCancelled => json.flag('tripCancelled');
  String? get leg => json.strOrNull('leg');
  Json? get group => json.objOrNull('group');
  Json? get otherLeg => group?.objOrNull('otherLeg');
  String? get paymentMethod => json.strOrNull('paymentMethod');
  String? get paymentStatus => json.strOrNull('paymentStatus');
  int get totalMinor => json.obj('amounts').integer('totalMinor');
  int get subtotalMinor => json.obj('amounts').integer('subtotalMinor');
  int get discountMinor => json.obj('amounts').integer('discountMinor');
  Trip get trip => Trip(json.obj('trip'));
  List<Ticket> get tickets => json.list('tickets').map(Ticket.new).toList();
  List<Ticket> get activeTickets => tickets.where((t) => t.active).toList();
  Json? get payment => json.objOrNull('payment');
  List<Json> get refunds => json.list('refunds');
  Json? get rating => json.objOrNull('rating');
  Json get actions => json.obj('actions');
  bool get canCancel => actions.flag('canCancel');
  bool get canChangeSeat => actions.flag('canChangeSeat');
  bool get canChangeTrip => actions.flag('canChangeTrip');
  bool get canRate => actions.flag('canRate');
  bool get canPay => actions.flag('canPay');
  int get changeCount => json.integer('changeCount');
  String? get replacedByBookingId => json.strOrNull('replacedByBookingId');
  DateTime? get createdAt => json.date('createdAt');
  DateTime? get cancelledAt => json.date('cancelledAt');
  bool get isCash => paymentMethod == 'CASH_ON_BOARD';
  int get cashToCollectMinor => tickets.fold(0, (n, t) => n + t.cashToCollectMinor);
  bool get isConfirmed => status == 'CONFIRMED';
}

/// GET /customer/bookings/:id/live
class LiveTrip {
  LiveTrip(this.json);

  final Json json;
  String get status => json.str('status');
  Json? get position => json.objOrNull('position');
  double? get lat => position?.numOrNull('lat');
  double? get lng => position?.numOrNull('lng');
  int get progressPercent => json.integer('progressPercent');
  int? get remainingKm => json.intOrNull('remainingKm');
  DateTime? get etaAt => json.date('etaAt');
  int get delayMinutes => json.integer('delayMinutes');
  String? get nextStopName {
    final n = json.objOrNull('nextStop');
    if (n == null) return null;
    final city = n.obj('city').str('nameAr');
    final station = n.str('nameAr');
    return city.isEmpty || city == station ? station : '$city — $station';
  }

  List<Json> get timeline => json.list('timeline');
  Json get vehicle => json.obj('vehicle');
  Json get driver => json.obj('driver');
  int get pollSeconds => json.integer('pollSeconds', 15);
  bool get moving => status == 'BOARDING' || status == 'IN_PROGRESS';
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

/// GET /public/destinations/popular item.
class Destination {
  Destination(this.json);

  final Json json;
  Json get city => json.obj('city');
  String get cityId => city.str('id');
  String get name => city.str('nameAr');
  String? get imageUrl => json.strOrNull('imageUrl');
  int get fromPriceMinor => json.integer('fromPriceMinor');
}
