import '../../domain/entities/product_extraction.dart';

class ProductExtractionResponseModel {
  final DateTime expirationDate;
  final String productName;
  final String? suggestedStorageSpotId;
  final String productType;
  final double? priceAmount;
  final String? currency;

  const ProductExtractionResponseModel({
    required this.expirationDate,
    required this.productName,
    required this.suggestedStorageSpotId,
    required this.productType,
    required this.priceAmount,
    required this.currency,
  });

  factory ProductExtractionResponseModel.fromJson(Map<String, dynamic> json) {
    return ProductExtractionResponseModel(
      expirationDate: DateTime.parse(json['expirationDate'] as String),
      productName: json['productName'] as String,
      suggestedStorageSpotId: json['suggestedStorageSpotId'] as String?,
      productType: json['productType'] as String,
      priceAmount: (json['priceAmount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
    );
  }

  ProductExtraction toEntity() {
    return ProductExtraction(
      expirationDate: expirationDate,
      productName: productName,
      suggestedStorageSpotId: suggestedStorageSpotId,
      productType: productType,
      priceAmount: priceAmount,
      currency: currency,
    );
  }
}
