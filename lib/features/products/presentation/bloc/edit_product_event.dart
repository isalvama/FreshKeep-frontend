part of 'edit_product_bloc.dart';

sealed class EditProductEvent {
  const EditProductEvent();
}

final class EditProductNameChanged extends EditProductEvent {
  final String name;

  const EditProductNameChanged(this.name);
}

final class EditProductExpirationDateChanged extends EditProductEvent {
  final DateTime expirationDate;

  const EditProductExpirationDateChanged(this.expirationDate);
}

final class EditProductTypeChanged extends EditProductEvent {
  final ProductType productType;

  const EditProductTypeChanged(this.productType);
}

final class EditProductAmountChanged extends EditProductEvent {
  final String amountText;

  const EditProductAmountChanged(this.amountText);
}

final class EditProductCurrencyChanged extends EditProductEvent {
  final Currency currency;

  const EditProductCurrencyChanged(this.currency);
}

final class EditProductSaveSubmitted extends EditProductEvent {
  const EditProductSaveSubmitted();
}
