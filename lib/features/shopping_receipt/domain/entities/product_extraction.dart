import 'package:equatable/equatable.dart';

class ProductExtraction extends Equatable {
  final DateTime expirationDate;
  final String productName;
  final String? suggestedStorageSpotId;
  final String productType;
  final double? priceAmount;
  final String? currency;
  final bool manuallyEditedExpirationDate;

  const ProductExtraction({
    required this.expirationDate,
    required this.productName,
    required this.suggestedStorageSpotId,
    required this.productType,
    required this.priceAmount,
    required this.currency,
    this.manuallyEditedExpirationDate = false,
  });

  ProductExtraction copyWith({
    DateTime? expirationDate,
    bool? manuallyEditedExpirationDate,
  }) {
    return ProductExtraction(
      expirationDate: expirationDate ?? this.expirationDate,
      productName: productName,
      suggestedStorageSpotId: suggestedStorageSpotId,
      productType: productType,
      priceAmount: priceAmount,
      currency: currency,
      manuallyEditedExpirationDate:
          manuallyEditedExpirationDate ?? this.manuallyEditedExpirationDate,
    );
  }

  @override
  List<Object?> get props => [
    expirationDate,
    productName,
    suggestedStorageSpotId,
    productType,
    priceAmount,
    currency,
    manuallyEditedExpirationDate,
  ];
}
