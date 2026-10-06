import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/core/theme/app_colors.dart';
import 'package:fresh_keep_frontend/shared/widgets/expiration_date_badge.dart';

final _today = DateTime(2026, 11, 12, 18, 30);

void main() {
  test('formats the date as day, short month name and year', () {
    expect(formatExpirationDate(DateTime(2026, 11, 12)), '12 Nov 2026');
    expect(formatExpirationDate(DateTime(2027, 1, 3)), '3 Jan 2027');
  });

  group('expirationUrgency', () {
    test('today, at any time of day, has expired', () {
      expect(
        expirationUrgency(DateTime(2026, 11, 12, 23, 59), _today),
        ExpirationUrgency.expired,
      );
    });

    test('a past date has expired', () {
      expect(
        expirationUrgency(DateTime(2026, 10, 1), _today),
        ExpirationUrgency.expired,
      );
    });

    test('tomorrow up to 7 days ahead is soon', () {
      expect(
        expirationUrgency(DateTime(2026, 11, 13), _today),
        ExpirationUrgency.soon,
      );
      expect(
        expirationUrgency(DateTime(2026, 11, 19), _today),
        ExpirationUrgency.soon,
      );
    });

    test('8 days ahead or more is later', () {
      expect(
        expirationUrgency(DateTime(2026, 11, 20), _today),
        ExpirationUrgency.later,
      );
    });
  });

  group('ExpirationDateBadge', () {
    Future<Color?> pumpBadge(WidgetTester tester, DateTime date) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExpirationDateBadge(date: date, today: _today),
        ),
      );
      final box =
          tester.widget<Container>(find.byType(Container)).decoration
              as BoxDecoration;
      return box.color;
    }

    testWidgets('shows the formatted date', (tester) async {
      await pumpBadge(tester, DateTime(2026, 11, 12));
      expect(find.text('12 Nov 2026'), findsOneWidget);
    });

    testWidgets('is red when expired, yellow when soon, neutral otherwise', (
      tester,
    ) async {
      expect(
        await pumpBadge(tester, DateTime(2026, 11, 12)),
        AppColors.expiredLight,
      );
      expect(
        await pumpBadge(tester, DateTime(2026, 11, 15)),
        AppColors.expiringSoonLight,
      );
      expect(
        await pumpBadge(tester, DateTime(2026, 12, 1)),
        AppColors.outlineLight,
      );
    });
  });
}
