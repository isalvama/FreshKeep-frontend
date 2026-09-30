import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/currency.dart';

void main() {
  test('mirrors the 42 backend constants, in backend order', () {
    expect(Currency.values.map((c) => c.name), [
      'USD', 'EUR', 'GBP', 'JPY', 'CHF', 'CAD', 'AUD', 'NZD', //
      'SEK', 'NOK', 'DKK', 'PLN', 'CZK', 'HUF', 'RON', 'BGN', //
      'MXN', 'BRL', 'ARS', 'CLP', 'COP', 'PEN', 'UYU', //
      'CNY', 'HKD', 'SGD', 'INR', 'KRW', 'THB', 'IDR', 'MYR', 'PHP', 'VND', //
      'AED', 'SAR', 'ILS', 'TRY', 'ZAR', 'EGP', 'NGN', //
      'UAH', 'RUB',
    ]);
  });

  test('carries the display name and symbol', () {
    expect(Currency.CHF.displayName, 'Swiss Franc');
    expect(Currency.CHF.symbol, 'CHf');
    expect(Currency.UYU.symbol, r'$U');
  });

  test('label is "CODE — Display name (symbol)"', () {
    expect(Currency.EUR.label, 'EUR — Euro (€)');
    expect(Currency.USD.label, r'USD — United States Dollar ($)');
  });

  group('tryParse', () {
    test('returns the constant for a known name', () {
      expect(Currency.tryParse('JPY'), Currency.JPY);
    });

    test('returns null for an unknown name, a symbol, a display name or '
        'null', () {
      expect(Currency.tryParse('XYZ'), isNull);
      expect(Currency.tryParse('€'), isNull);
      expect(Currency.tryParse('Euro'), isNull);
      expect(Currency.tryParse(null), isNull);
    });
  });
}
