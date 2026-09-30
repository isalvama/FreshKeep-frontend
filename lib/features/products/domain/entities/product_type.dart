// Values mirror the backend's `ProductType` constants, so `.name` is exactly
// what the API accepts.
// ignore_for_file: constant_identifier_names

enum ProductType {
  FRUITS,
  VEGETABLES,
  OTHER_FRESH_PRODUCTS,
  MEAT,
  SEAFOOD,
  DAIRY,
  DELI,
  BAKERY,
  PANTRY,
  SNACKS,
  SWEETS,
  FROZEN_FOODS,
  ICE_CREAM_AND_DESSERTS,
  BEVERAGES,
  INTERNATIONAL,
  SAUCES,
  OTHER;

  /// `OTHER_FRESH_PRODUCTS` → "Other fresh products".
  String get label {
    final words = name.toLowerCase().replaceAll('_', ' ');
    return words[0].toUpperCase() + words.substring(1);
  }

  /// Null if [value] is not a known constant.
  static ProductType? tryParse(String? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
