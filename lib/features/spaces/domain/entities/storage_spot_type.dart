enum StorageSpotType {
  fridge,
  freezer,
  pantry,
  fruitBowl,
  wineCellar,
  countertop,
  shelf;

  static const Map<StorageSpotType, String> _wireValues = {
    StorageSpotType.fridge: 'FRIDGE',
    StorageSpotType.freezer: 'FREEZER',
    StorageSpotType.pantry: 'PANTRY',
    StorageSpotType.fruitBowl: 'FRUIT_BOWL',
    StorageSpotType.wineCellar: 'WINE_CELLAR',
    StorageSpotType.countertop: 'COUNTERTOP',
    StorageSpotType.shelf: 'SHELF',
  };

  String get wireValue => _wireValues[this]!;

  static StorageSpotType fromWireValue(String value) {
    return _wireValues.entries.firstWhere((entry) => entry.value == value).key;
  }
}
