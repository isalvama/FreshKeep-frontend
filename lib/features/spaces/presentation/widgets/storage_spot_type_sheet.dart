import 'package:flutter/material.dart';

import '../../domain/entities/storage_spot_type.dart';
import '../../../../core/constants/ui_constants.dart';
import '../../../../shared/widgets/storage_spot_type_icon.dart';

const Map<StorageSpotType, String> _typeLabels = {
  StorageSpotType.fridge: 'Fridge',
  StorageSpotType.freezer: 'Freezer',
  StorageSpotType.pantry: 'Pantry',
  StorageSpotType.fruitBowl: 'Fruit Bowl',
  StorageSpotType.wineCellar: 'Wine Cellar',
  StorageSpotType.countertop: 'Countertop',
  StorageSpotType.shelf: 'Shelf',
};

String storageSpotTypeLabel(StorageSpotType type) => _typeLabels[type]!;

Future<StorageSpotType?> showStorageSpotTypeSheet(
  BuildContext context, {
  required StorageSpotType selected,
}) {
  return showModalBottomSheet<StorageSpotType>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kCornerRadius)),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Text(
                  'Storage Spot Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (final type in StorageSpotType.values)
                ListTile(
                  leading: StorageSpotTypeIcon(type: type),
                  title: Text(storageSpotTypeLabel(type)),
                  trailing: type == selected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(type),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
