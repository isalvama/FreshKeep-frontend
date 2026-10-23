import 'package:equatable/equatable.dart';

class PersistedProduct extends Equatable {
  final String id;
  final String productName;
  final DateTime expirationDate;
  final String? storageSpotId;
  final String productType;
  final double? priceAmount;
  final String? currency;

  const PersistedProduct({
    required this.id,
    required this.productName,
    required this.expirationDate,
    required this.storageSpotId,
    required this.productType,
    required this.priceAmount,
    required this.currency,
  });

  @override
  List<Object?> get props => [
    id,
    productName,
    expirationDate,
    storageSpotId,
    productType,
    priceAmount,
    currency,
  ];
}
