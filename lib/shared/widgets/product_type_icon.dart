import 'package:flutter/material.dart';

import '../../features/products/domain/entities/product_type.dart';
import '../../resources/assets.dart';

/// The image for a product type. Null (an unknown backend value) gets the
/// "other" image.
String productTypeIconAsset(ProductType? type) {
  return switch (type) {
    ProductType.FRUITS => Assets.fruitsIcon,
    ProductType.VEGETABLES => Assets.vegetablesIcon,
    ProductType.OTHER_FRESH_PRODUCTS => Assets.otherFreshFoodsIcon,
    ProductType.MEAT => Assets.meatIcon,
    ProductType.SEAFOOD => Assets.seafoodIcon,
    ProductType.DAIRY => Assets.dairyIcon,
    ProductType.DELI => Assets.deliIcon,
    ProductType.BAKERY => Assets.bakeryIcon,
    ProductType.PANTRY => Assets.pantryIcon,
    ProductType.SNACKS => Assets.snacksIcon,
    ProductType.SWEETS => Assets.sweetsIcon,
    ProductType.FROZEN_FOODS => Assets.frozenFoodsIcon,
    ProductType.ICE_CREAM_AND_DESSERTS => Assets.iceCreamAndDessertsIcon,
    ProductType.BEVERAGES => Assets.beveragesIcon,
    ProductType.INTERNATIONAL => Assets.internationalIcon,
    ProductType.SAUCES => Assets.saucesIcon,
    ProductType.OTHER || null => Assets.otherIcon,
  };
}

/// A square product type image. Decorative: the type is always shown as text
/// next to it, so it is left out of semantics.
class ProductTypeIcon extends StatelessWidget {
  const ProductTypeIcon({super.key, required this.type, this.size = 40});

  /// For entities that keep the backend's raw string, e.g. `"DAIRY"`.
  ProductTypeIcon.fromName(String? name, {Key? key, double size = 40})
    : this(key: key, type: ProductType.tryParse(name), size: size);

  final ProductType? type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      productTypeIconAsset(type),
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }
}
