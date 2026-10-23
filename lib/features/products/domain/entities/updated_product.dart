import 'package:equatable/equatable.dart';

/// The product as returned by `PATCH /api/v1/products/{id}`. [productType]
/// and [currency] stay raw strings, like on `PersistedProduct`, so an unknown
/// value from the backend never breaks parsing.
class UpdatedProduct extends Equatable {
  final String productId;
  final String name;
  final DateTime expirationDate;
  final String productType;
  final double? amount;
  final String? currency;

  const UpdatedProduct({
    required this.productId,
    required this.name,
    required this.expirationDate,
    required this.productType,
    required this.amount,
    required this.currency,
  });

  @override
  List<Object?> get props => [
    productId,
    name,
    expirationDate,
    productType,
    amount,
    currency,
  ];
}
