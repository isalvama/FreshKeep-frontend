import '../../domain/entities/persisted_product.dart';

class PersistedProductResponseModel {
  final String id;
  final String productName;
  final DateTime expirationDate;
  final String? storageSpotId;
  final String productType;
  final double? priceAmount;
  final String? currency;

  const PersistedProductResponseModel({
    required this.id,
    required this.productName,
    required this.expirationDate,
    required this.storageSpotId,
    required this.productType,
    required this.priceAmount,
    required this.currency,
  });

  factory PersistedProductResponseModel.fromJson(Map<String, dynamic> json) {
    return PersistedProductResponseModel(
      id: json['id'] as String,
      productName: json['productName'] as String,
      expirationDate: DateTime.parse(json['expirationDate'] as String),
      storageSpotId: json['storageSpotId'] as String?,
      productType: json['productType'] as String,
      priceAmount: (json['priceAmount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
    );
  }

  PersistedProduct toEntity() {
    return PersistedProduct(
      id: id,
      productName: productName,
      expirationDate: expirationDate,
      storageSpotId: storageSpotId,
      productType: productType,
      priceAmount: priceAmount,
      currency: currency,
    );
  }
}
