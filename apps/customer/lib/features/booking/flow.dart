import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// Seats held on one leg (labels sorted; passenger i sits in seats[i]).
class LegSelection {
  const LegSelection({required this.trip, required this.seats, required this.holdIds, required this.expiresAt});

  final Trip trip;
  final List<Seat> seats;
  final List<String> holdIds;
  final DateTime expiresAt;

  List<String> get labels => seats.map((s) => s.label).toList();
  String get labelText => labels.join('، ');
}

class PassengerDraft {
  const PassengerDraft({this.fullName = '', this.phone = '', this.idNumber = '', this.gender});

  final String fullName;
  final String phone;
  final String idNumber;
  final String? gender;

  PassengerDraft copyWith({String? fullName, String? phone, String? idNumber, String? Function()? gender}) => PassengerDraft(
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        idNumber: idNumber ?? this.idNumber,
        gender: gender == null ? this.gender : gender(),
      );

  /// Customer API passenger: fullName 2–160, gender required, phone / idNumber optional.
  Json toJson() {
    final p = phone.trim();
    return {
      'fullName': fullName.trim(),
      'gender': gender,
      if (p.isNotEmpty) 'phone': normalizeSudanPhone(p) ?? latinDigits(p),
      if (idNumber.trim().isNotEmpty) 'idNumber': latinDigits(idNumber.trim()),
    };
  }
}

({String? name, String? gender, String? phone}) validatePassenger(PassengerDraft p, {required bool womenOnly}) {
  final digits = latinDigits(p.phone).replaceAll(RegExp(r'\D'), '');
  return (
    name: p.fullName.trim().length < 2 ? 'الاسم مطلوب (حرفان على الأقل).' : null,
    gender: p.gender == null ? 'اختر الجنس.' : (womenOnly && p.gender != 'FEMALE' ? 'مقعد مخصّص للسيدات: اختر «أنثى».' : null),
    phone: p.phone.trim().isNotEmpty && (digits.length < 6 || digits.length > 15) ? 'رقم جوال غير صحيح.' : null,
  );
}

class BookingFlowState {
  const BookingFlowState({
    this.search,
    this.outbound,
    this.inbound,
    this.passengers = const [],
    this.couponCode,
    this.idempotencyKey,
  });

  final TripSearchValue? search;
  final LegSelection? outbound;
  final LegSelection? inbound;
  final List<PassengerDraft> passengers;
  final String? couponCode;
  final String? idempotencyKey;

  int get passengerCount => search?.passengers ?? 1;
  bool get roundTrip => search?.roundTrip ?? false;

  DateTime? get expiresAt {
    final t = [outbound?.expiresAt, inbound?.expiresAt].whereType<DateTime>().toList()..sort();
    return t.isEmpty ? null : t.first;
  }

  List<String> get allHoldIds => [...?outbound?.holdIds, ...?inbound?.holdIds];

  bool womenOnlyAt(int i) =>
      (outbound != null && i < outbound!.seats.length && outbound!.seats[i].womenOnly) ||
      (inbound != null && i < inbound!.seats.length && inbound!.seats[i].womenOnly);

  /// Quote / create body (D-RT-01: the holds of both legs, the same passengers).
  Json body() => {
        'holdIds': allHoldIds,
        'passengers': passengers.map((p) => p.toJson()).toList(),
        if (couponCode != null && couponCode!.isNotEmpty) 'couponCode': couponCode,
      };

  BookingFlowState copyWith({
    TripSearchValue? search,
    LegSelection? Function()? outbound,
    LegSelection? Function()? inbound,
    List<PassengerDraft>? passengers,
    String? Function()? couponCode,
    String? Function()? idempotencyKey,
  }) =>
      BookingFlowState(
        search: search ?? this.search,
        outbound: outbound == null ? this.outbound : outbound(),
        inbound: inbound == null ? this.inbound : inbound(),
        passengers: passengers ?? this.passengers,
        couponCode: couponCode == null ? this.couponCode : couponCode(),
        idempotencyKey: idempotencyKey == null ? this.idempotencyKey : idempotencyKey(),
      );
}

/// Search → results → trip → seats → passengers → review → payment.
class BookingFlow extends Notifier<BookingFlowState> {
  @override
  BookingFlowState build() => const BookingFlowState();

  void setSearch(TripSearchValue search) {
    _release(state.allHoldIds);
    state = BookingFlowState(search: search, passengers: state.passengers);
  }

  void setLeg({required bool isReturn, required LegSelection selection}) {
    final old = isReturn ? state.inbound : state.outbound;
    if (old != null) _release(old.holdIds.where((id) => !selection.holdIds.contains(id)));
    state = isReturn
        ? state.copyWith(inbound: () => selection, idempotencyKey: () => null)
        : state.copyWith(outbound: () => selection, idempotencyKey: () => null);
    final n = state.passengerCount;
    if (state.passengers.length != n) {
      state = state.copyWith(passengers: List.generate(n, (i) => i < state.passengers.length ? state.passengers[i] : const PassengerDraft()));
    }
  }

  void clearLegs() {
    _release(state.allHoldIds);
    state = state.copyWith(outbound: () => null, inbound: () => null, idempotencyKey: () => null);
  }

  void setPassenger(int i, PassengerDraft p) {
    final list = [...state.passengers];
    list[i] = p;
    state = state.copyWith(passengers: list, idempotencyKey: () => null);
  }

  void setCoupon(String? code) => state = state.copyWith(couponCode: () => code, idempotencyKey: () => null);

  String ensureIdempotencyKey(String Function() create) {
    final key = state.idempotencyKey ?? create();
    if (state.idempotencyKey == null) state = state.copyWith(idempotencyKey: () => key);
    return key;
  }

  /// Holds are consumed by the booking; keep the search for "book again".
  void completed() => state = state.copyWith(outbound: () => null, inbound: () => null, couponCode: () => null, idempotencyKey: () => null);

  void _release(Iterable<String> ids) {
    final list = ids.toList();
    if (list.isNotEmpty) ref.read(apiProvider).releaseHolds(list);
  }
}

final bookingFlowProvider = NotifierProvider<BookingFlow, BookingFlowState>(BookingFlow.new);
