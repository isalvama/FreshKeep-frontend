import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/product_type.dart';

void main() {
  test('mirrors the 17 backend constants, in backend order', () {
    expect(ProductType.values.map((t) => t.name), [
      'FRUITS',
      'VEGETABLES',
      'OTHER_FRESH_PRODUCTS',
      'MEAT',
      'SEAFOOD',
      'DAIRY',
      'DELI',
      'BAKERY',
      'PANTRY',
      'SNACKS',
      'SWEETS',
      'FROZEN_FOODS',
      'ICE_CREAM_AND_DESSERTS',
      'BEVERAGES',
      'INTERNATIONAL',
      'SAUCES',
      'OTHER',
    ]);
  });

  test('label is sentence case with spaces', () {
    expect(ProductType.OTHER_FRESH_PRODUCTS.label, 'Other fresh products');
    expect(ProductType.ICE_CREAM_AND_DESSERTS.label, 'Ice cream and desserts');
    expect(ProductType.DAIRY.label, 'Dairy');
  });

  group('tryParse', () {
    test('returns the constant for a known name', () {
      expect(ProductType.tryParse('FROZEN_FOODS'), ProductType.FROZEN_FOODS);
    });

    test('returns null for an unknown name, a label or null', () {
      expect(ProductType.tryParse('CANNED'), isNull);
      expect(ProductType.tryParse('Dairy'), isNull);
      expect(ProductType.tryParse(null), isNull);
    });
  });
}
