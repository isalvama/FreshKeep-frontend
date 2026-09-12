import 'package:equatable/equatable.dart';

class ProductExtraction extends Equatable {
  final DateTime expirationDate;
  final String productName;
  final String? suggestedStorageSpotId;
  final String productType;
  final double? priceAmount;
  final String? currency;

  const ProductExtraction({
    required this.expirationDate,
    required this.productName,
    required this.suggestedStorageSpotId,
    required this.productType,
    required this.priceAmount,
    required this.currency,
  });

  @override
  List<Object?> get props => [
    expirationDate,
    productName,
    suggestedStorageSpotId,
    productType,
    priceAmount,
    currency,
  ];
}
