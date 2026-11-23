import 'package:broker/data/models.dart';
import 'package:broker/features/booking/flow.dart';
import 'package:flutter_test/flutter_test.dart';

BrokerTrip _trip(String id) => BrokerTrip({'id': id, 'basePrice': 3500000, 'seatsFree': 10});

TripSeat _seat(String id, String label, {bool women = false}) =>
    TripSeat({'id': id, 'label': label, 'status': 'FREE', 'isWomenOnly': women});

void main() {
  group('passenger validation', () {
    test('name and phone are required', () {
      final e = validatePassenger(const PassengerDraft(), womenOnly: false);
      expect(e.name, isNotNull);
      expect(e.phone, isNotNull);
      expect(e.gender, isNull);
    });

    test('women-only seat requires FEMALE', () {
      const male = PassengerDraft(fullName: 'Ali Omer', phone: '0912345678', gender: 'MALE');
      expect(validatePassenger(male, womenOnly: true).gender, isNotNull);
      expect(validatePassenger(male.copyWith(gender: () => 'FEMALE'), womenOnly: true).gender, isNull);
    });

    test('API body: E.164 phone, Latin digits, optional fields omitted', () {
      const p = PassengerDraft(fullName: ' سارة أحمد ', phone: '٠٩١٢٣٤٥٦٧٨', idNumber: '');
      expect(p.toJson(), {'fullName': 'سارة أحمد', 'phone': '+249912345678'});
    });
  });

  group('round trip body', () {
    test('returnTrip carries the second leg; passenger i sits in seat i of each leg', () {
      final state = BookingFlowState(
        passengerCount: 2,
        roundTrip: true,
        outbound: LegSelection(trip: _trip('t1'), seats: [_seat('a', '1'), _seat('b', '2', women: true)], holdIds: const ['h1', 'h2'], expiresAt: DateTime(2030)),
        inbound: LegSelection(trip: _trip('t2'), seats: [_seat('c', '5'), _seat('d', '6')], holdIds: const ['h3', 'h4'], expiresAt: DateTime(2029)),
        passengers: const [PassengerDraft(fullName: 'A B', phone: '0911111111'), PassengerDraft(fullName: 'C D', phone: '0922222222')],
      );
      final body = state.body();
      expect(body['tripId'], 't1');
      expect(body['seatIds'], ['a', 'b']);
      expect(body['returnTrip'], {'tripId': 't2', 'seatIds': ['c', 'd']});
      expect(state.womenOnlyAt(1), isTrue);
      expect(state.womenOnlyAt(0), isFalse);
      expect(state.expiresAt, DateTime(2029)); // the earliest hold
      expect(state.allHoldIds, ['h1', 'h2', 'h3', 'h4']);
    });
  });

  group('quote', () {
    test('round trip totals and the daily ceiling count both legs', () {
      final q = BookingQuote({
        'seatCount': 2,
        'totalAmountMinor': 7000000,
        'expectedCommissionMinor': 700000,
        'combinedTotalMinor': 14000000,
        'combinedCommissionMinor': 1400000,
        'sufficientBalance': true,
        'exposure': {'ceiling': 10, 'usedToday': 7},
        'returnLeg': {'seatCount': 2, 'totalAmountMinor': 7000000},
      });
      expect(q.grandTotalMinor, 14000000);
      expect(q.grandCommissionMinor, 1400000);
      expect(q.withinCeiling, isFalse); // 7 + 4 > 10
    });
  });

  group('booking', () {
    test('only confirmed bookings before departure can be modified', () {
      final future = DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String();
      final past = DateTime.now().subtract(const Duration(hours: 1)).toUtc().toIso8601String();
      expect(Booking({'status': 'CONFIRMED', 'trip': {'departureAt': future}}).canModify, isTrue);
      expect(Booking({'status': 'CONFIRMED', 'trip': {'departureAt': past}}).canModify, isFalse);
      expect(Booking({'status': 'CANCELLED', 'trip': {'departureAt': future}}).canModify, isFalse);
    });
  });
}
