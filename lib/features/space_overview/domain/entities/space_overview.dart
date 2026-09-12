import 'package:equatable/equatable.dart';

import '../../../shopping_receipt/domain/entities/persisted_product.dart';
import '../../../spaces/domain/entities/storage_spot.dart';

class SpaceOverview extends Equatable {
  final String id;
  final String name;
  final String emoji;
  final List<StorageSpot> storageSpots;
  final List<PersistedProduct> productResults;

  const SpaceOverview({
    required this.id,
    required this.name,
    required this.emoji,
    required this.storageSpots,
    required this.productResults,
  });

  @override
  List<Object?> get props => [id, name, emoji, storageSpots, productResults];
}
