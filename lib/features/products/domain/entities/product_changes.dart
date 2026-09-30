import 'package:equatable/equatable.dart';

import 'currency.dart';
import 'product_type.dart';

/// The fields to change on a product. A null field is unchanged and is never
/// sent to the backend.
class ProductChanges extends Equatable {
  final String? name;
  final DateTime? expirationDate;
  final ProductType? productType;
  final double? amount;
  final Currency? currency;

  const ProductChanges({
    this.name,
    this.expirationDate,
    this.productType,
    this.amount,
    this.currency,
  });

  bool get isEmpty =>
      name == null &&
      expirationDate == null &&
      productType == null &&
      amount == null &&
      currency == null;

  @override
  List<Object?> get props => [
    name,
    expirationDate,
    productType,
    amount,
    currency,
  ];
}
