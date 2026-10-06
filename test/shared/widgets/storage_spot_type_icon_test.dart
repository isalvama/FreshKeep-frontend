import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_type.dart';
import 'package:fresh_keep_frontend/resources/assets.dart';
import 'package:fresh_keep_frontend/shared/widgets/storage_spot_type_icon.dart';

void main() {
  test('every storage spot type has its own image, and each file exists', () {
    final paths = StorageSpotType.values.map(storageSpotTypeIconAsset).toList();

    expect(paths.toSet(), hasLength(StorageSpotType.values.length));
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  testWidgets('shows the image for the type', (tester) async {
    await tester.pumpWidget(
      const StorageSpotTypeIcon(type: StorageSpotType.fruitBowl),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, Assets.fruitBowlSpotIcon);
  });
}
