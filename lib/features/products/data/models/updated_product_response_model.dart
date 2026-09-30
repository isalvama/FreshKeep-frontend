import '../../domain/entities/updated_product.dart';

class UpdatedProductResponseModel {
  final String productId;
  final String name;
  final DateTime expirationDate;
  final String productType;
  final double? amount;
  final String? currency;

  const UpdatedProductResponseModel({
    required this.productId,
    required this.name,
    required this.expirationDate,
    required this.productType,
    required this.amount,
    required this.currency,
  });

  factory UpdatedProductResponseModel.fromJson(Map<String, dynamic> json) {
    return UpdatedProductResponseModel(
      productId: json['productId'] as String,
      name: json['name'] as String,
      expirationDate: DateTime.parse(json['expirationDate'] as String),
      productType: json['productType'] as String,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
    );
  }

  UpdatedProduct toEntity() {
    return UpdatedProduct(
      productId: productId,
      name: name,
      expirationDate: expirationDate,
      productType: productType,
      amount: amount,
      currency: currency,
    );
  }
}
