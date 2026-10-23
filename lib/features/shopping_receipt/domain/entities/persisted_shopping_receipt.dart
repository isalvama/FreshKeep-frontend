import 'package:equatable/equatable.dart';

import '../../../spaces/domain/entities/storage_spot.dart';
import 'persisted_product.dart';

class PersistedShoppingReceipt extends Equatable {
  final String id;
  final DateTime shoppingDate;
  final String storeName;
  final List<PersistedProduct> products;
  final List<StorageSpot> storageSpots;

  const PersistedShoppingReceipt({
    required this.id,
    required this.shoppingDate,
    required this.storeName,
    required this.products,
    required this.storageSpots,
  });

  @override
  List<Object?> get props => [
    id,
    shoppingDate,
    storeName,
    products,
    storageSpots,
  ];
}
