import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/product_type.dart';
import 'package:fresh_keep_frontend/resources/assets.dart';
import 'package:fresh_keep_frontend/shared/widgets/product_type_icon.dart';

void main() {
  test('every product type has its own image, and each file exists', () {
    final paths = ProductType.values.map(productTypeIconAsset).toList();

    expect(paths.toSet(), hasLength(ProductType.values.length));
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('an unknown type gets the "other" image', () {
    expect(productTypeIconAsset(null), Assets.otherIcon);
  });

  testWidgets('fromName shows the image for a backend name', (tester) async {
    await tester.pumpWidget(ProductTypeIcon.fromName('DAIRY'));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, Assets.dairyIcon);
  });

  testWidgets('fromName falls back to "other" for an unknown name', (
    tester,
  ) async {
    await tester.pumpWidget(ProductTypeIcon.fromName('CANNED'));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, Assets.otherIcon);
  });
}
