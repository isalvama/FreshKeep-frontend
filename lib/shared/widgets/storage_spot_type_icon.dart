import 'package:flutter/material.dart';

import '../../features/spaces/domain/entities/storage_spot_type.dart';
import '../../resources/assets.dart';

/// The image for a storage spot type.
String storageSpotTypeIconAsset(StorageSpotType type) {
  return switch (type) {
    StorageSpotType.fridge => Assets.fridgeSpotIcon,
    StorageSpotType.freezer => Assets.freezerSpotIcon,
    StorageSpotType.pantry => Assets.pantrySpotIcon,
    StorageSpotType.fruitBowl => Assets.fruitBowlSpotIcon,
    StorageSpotType.wineCellar => Assets.wineCellarSpotIcon,
    StorageSpotType.countertop => Assets.countertopSpotIcon,
    StorageSpotType.shelf => Assets.shelfSpotIcon,
  };
}

/// A square storage spot type image. Decorative: the type is always shown as
/// text next to it, so it is left out of semantics.
class StorageSpotTypeIcon extends StatelessWidget {
  const StorageSpotTypeIcon({super.key, required this.type, this.size = 40});

  final StorageSpotType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      storageSpotTypeIconAsset(type),
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }
}
