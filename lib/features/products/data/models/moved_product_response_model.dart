import '../../domain/entities/moved_product.dart';

class MovedProductResponseModel {
  final String productId;
  final String newStorageSpotId;
  final DateTime newExpirationDate;

  const MovedProductResponseModel({
    required this.productId,
    required this.newStorageSpotId,
    required this.newExpirationDate,
  });

  factory MovedProductResponseModel.fromJson(Map<String, dynamic> json) {
    return MovedProductResponseModel(
      productId: json['productId'] as String,
      newStorageSpotId: json['newStorageSpotId'] as String,
      newExpirationDate: DateTime.parse(json['newExpirationDate'] as String),
    );
  }

  MovedProduct toEntity() {
    return MovedProduct(
      productId: productId,
      newStorageSpotId: newStorageSpotId,
      newExpirationDate: newExpirationDate,
    );
  }
}
