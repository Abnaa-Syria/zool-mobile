import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// Seats held on one leg.
class LegSelection {
  const LegSelection({required this.trip, required this.seats, required this.holdIds, required this.expiresAt});

  final BrokerTrip trip;

  /// Sorted by label; passenger i sits in seats[i].
  final List<TripSeat> seats;
  final List<String> holdIds;
  final DateTime expiresAt;

  List<String> get seatIds => seats.map((s) => s.id).toList();
  String get seatLabels => seats.map((s) => s.label).join('، ');
}

/// Passenger form row while editing.
class PassengerDraft {
  const PassengerDraft({this.fullName = '', this.phone = '', this.idNumber = '', this.gender});

  final String fullName;
  final String phone;
  final String idNumber;

  /// 'MALE' | 'FEMALE' | null
  final String? gender;

  PassengerDraft copyWith({String? fullName, String? phone, String? idNumber, String? Function()? gender}) => PassengerDraft(
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        idNumber: idNumber ?? this.idNumber,
        gender: gender == null ? this.gender : gender(),
      );

  /// Broker API passenger: fullName 2–160, phone 7–32, idNumber ≤ 64, gender optional.
  Json toJson() {
    final phone = normalizeSudanPhone(this.phone) ?? latinDigits(this.phone.trim());
    return {
      'fullName': fullName.trim(),
      'phone': phone,
      if (idNumber.trim().isNotEmpty) 'idNumber': latinDigits(idNumber.trim()),
      'gender': ?gender,
    };
  }
}

/// Validation errors for one passenger (null fields = valid).
({String? name, String? phone, String? gender}) validatePassenger(PassengerDraft p, {required bool womenOnly}) {
  final name = p.fullName.trim();
  final digits = latinDigits(p.phone).replaceAll(RegExp(r'\D'), '');
  return (
    name: name.length < 2 ? 'الاسم مطلوب (حرفان على الأقل).' : null,
    phone: p.phone.trim().isEmpty ? 'رقم الجوال مطلوب.' : (digits.length < 7 || digits.length > 15 ? 'رقم جوال غير صحيح.' : null),
    gender: womenOnly && p.gender != 'FEMALE' ? 'مقعد مخصّص للسيدات: اختر «أنثى».' : null,
  );
}

class BookingFlowState {
  const BookingFlowState({
    this.fromCity,
    this.toCity,
    this.date,
    this.passengerCount = 1,
    this.roundTrip = false,
    this.returnDate,
    this.outbound,
    this.inbound,
    this.passengers = const [],
    this.idempotencyKey,
  });

  final City? fromCity;
  final City? toCity;
  final DateTime? date;
  final int passengerCount;
  final bool roundTrip;
  final DateTime? returnDate;
  final LegSelection? outbound;
  final LegSelection? inbound;
  final List<PassengerDraft> passengers;

  /// One key per purchase attempt; reused when retrying after a network failure.
  final String? idempotencyKey;

  /// The earliest hold expiry across both legs.
  DateTime? get expiresAt {
    final times = [outbound?.expiresAt, inbound?.expiresAt].whereType<DateTime>().toList()..sort();
    return times.isEmpty ? null : times.first;
  }

  List<String> get allHoldIds => [...?outbound?.holdIds, ...?inbound?.holdIds];

  /// Passenger i sits in a women-only seat on any leg.
  bool womenOnlyAt(int i) =>
      (outbound != null && i < outbound!.seats.length && outbound!.seats[i].womenOnly) ||
      (inbound != null && i < inbound!.seats.length && inbound!.seats[i].womenOnly);

  /// Quote / confirm body (D-RT-01: `returnTrip` for the second leg, same passengers).
  Json body() => {
        'tripId': outbound!.trip.id,
        'seatIds': outbound!.seatIds,
        'passengers': passengers.map((p) => p.toJson()).toList(),
        if (inbound != null) 'returnTrip': {'tripId': inbound!.trip.id, 'seatIds': inbound!.seatIds},
      };

  BookingFlowState copyWith({
    City? fromCity,
    City? toCity,
    DateTime? date,
    int? passengerCount,
    bool? roundTrip,
    DateTime? Function()? returnDate,
    LegSelection? Function()? outbound,
    LegSelection? Function()? inbound,
    List<PassengerDraft>? passengers,
    String? Function()? idempotencyKey,
  }) =>
      BookingFlowState(
        fromCity: fromCity ?? this.fromCity,
        toCity: toCity ?? this.toCity,
        date: date ?? this.date,
        passengerCount: passengerCount ?? this.passengerCount,
        roundTrip: roundTrip ?? this.roundTrip,
        returnDate: returnDate == null ? this.returnDate : returnDate(),
        outbound: outbound == null ? this.outbound : outbound(),
        inbound: inbound == null ? this.inbound : inbound(),
        passengers: passengers ?? this.passengers,
        idempotencyKey: idempotencyKey == null ? this.idempotencyKey : idempotencyKey(),
      );
}

/// New-booking flow shared by the search → results → seats → passengers → review pages.
class BookingFlow extends Notifier<BookingFlowState> {
  @override
  BookingFlowState build() => const BookingFlowState();

  void setSearch({
    required City fromCity,
    required City toCity,
    required DateTime date,
    required int passengerCount,
    required bool roundTrip,
    DateTime? returnDate,
  }) {
    _release(state.allHoldIds);
    state = BookingFlowState(
      fromCity: fromCity,
      toCity: toCity,
      date: date,
      passengerCount: passengerCount,
      roundTrip: roundTrip,
      returnDate: roundTrip ? returnDate : null,
    );
  }

  void setLeg({required bool isReturn, required LegSelection selection}) {
    final old = isReturn ? state.inbound : state.outbound;
    if (old != null) _release(old.holdIds.where((id) => !selection.holdIds.contains(id)));
    state = isReturn
        ? state.copyWith(inbound: () => selection, idempotencyKey: () => null)
        : state.copyWith(outbound: () => selection, idempotencyKey: () => null);
    if (state.passengers.length != state.passengerCount) {
      state = state.copyWith(passengers: List.generate(state.passengerCount, (i) => i < state.passengers.length ? state.passengers[i] : const PassengerDraft()));
    }
  }

  /// Drops a leg (its holds are released); dropping the outbound also drops the return.
  void clearLeg({required bool isReturn}) {
    if (isReturn) {
      _release(state.inbound?.holdIds ?? const []);
      state = state.copyWith(inbound: () => null);
    } else {
      _release(state.allHoldIds);
      state = state.copyWith(outbound: () => null, inbound: () => null);
    }
  }

  void setPassenger(int i, PassengerDraft p) {
    final list = [...state.passengers];
    list[i] = p;
    state = state.copyWith(passengers: list, idempotencyKey: () => null);
  }

  String ensureIdempotencyKey(String Function() create) {
    final key = state.idempotencyKey ?? create();
    if (state.idempotencyKey == null) state = state.copyWith(idempotencyKey: () => key);
    return key;
  }

  /// After a confirmed booking (holds are consumed) — keeps the search for the next booking.
  void completed() {
    state = state.copyWith(outbound: () => null, inbound: () => null, passengers: const [], idempotencyKey: () => null);
  }

  /// Leaving the flow: release every hold.
  void abandon() {
    _release(state.allHoldIds);
    state = state.copyWith(outbound: () => null, inbound: () => null, idempotencyKey: () => null);
  }

  void _release(Iterable<String> holdIds) {
    final ids = holdIds.toList();
    if (ids.isNotEmpty) ref.read(apiProvider).releaseHolds(ids);
  }
}

final bookingFlowProvider = NotifierProvider<BookingFlow, BookingFlowState>(BookingFlow.new);
