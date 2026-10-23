import 'package:equatable/equatable.dart';

/// The result of `PATCH /api/v1/products/{id}/storage-spot`.
class MovedProduct extends Equatable {
  final String productId;
  final String newStorageSpotId;

  /// Recalculated by the backend (AI) as part of the move.
  final DateTime newExpirationDate;

  const MovedProduct({
    required this.productId,
    required this.newStorageSpotId,
    required this.newExpirationDate,
  });

  @override
  List<Object?> get props => [productId, newStorageSpotId, newExpirationDate];
}
