import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/utils/expiration_date_shift.dart';

void main() {
  test('shifts forward by the shopping-date delta', () {
    final result = shiftExpirationDate(
      original: DateTime(2026, 9, 15),
      fromShoppingDate: DateTime(2026, 9, 8),
      toShoppingDate: DateTime(2026, 9, 10),
    );

    expect(result, DateTime(2026, 9, 17));
  });

  test('shifts backward by the shopping-date delta', () {
    final result = shiftExpirationDate(
      original: DateTime(2026, 9, 15),
      fromShoppingDate: DateTime(2026, 9, 8),
      toShoppingDate: DateTime(2026, 9, 1),
    );

    expect(result, DateTime(2026, 9, 8));
  });

  test('a zero delta returns the original date', () {
    final result = shiftExpirationDate(
      original: DateTime(2026, 9, 15),
      fromShoppingDate: DateTime(2026, 9, 8),
      toShoppingDate: DateTime(2026, 9, 8),
    );

    expect(result, DateTime(2026, 9, 15));
  });

  test('crosses month and year boundaries', () {
    final result = shiftExpirationDate(
      original: DateTime(2026, 12, 28),
      fromShoppingDate: DateTime(2026, 12, 20),
      toShoppingDate: DateTime(2026, 12, 25),
    );

    expect(result, DateTime(2027, 1, 2));
  });

  test(
    'a range crossing a DST change stays at midnight on the correct day',
    () {
      // Most DST zones switch in late March; 7 calendar days apart here, even
      // though the local wall-clock difference may be 6 days and 23 hours.
      final result = shiftExpirationDate(
        original: DateTime(2026, 3, 20),
        fromShoppingDate: DateTime(2026, 3, 25),
        toShoppingDate: DateTime(2026, 4, 1),
      );

      expect(result, DateTime(2026, 3, 27));
      expect(result.hour, 0);
      expect(result.minute, 0);
    },
  );

  test('ignores the time-of-day component of the shopping dates', () {
    final result = shiftExpirationDate(
      original: DateTime(2026, 9, 15),
      fromShoppingDate: DateTime(2026, 9, 8, 23, 30),
      toShoppingDate: DateTime(2026, 9, 9, 0, 15),
    );

    expect(result, DateTime(2026, 9, 16));
  });
}
