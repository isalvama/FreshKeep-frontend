part of 'edit_product_bloc.dart';

sealed class ProductSaveStatus {
  const ProductSaveStatus();
}

final class ProductSaveIdle extends ProductSaveStatus {
  const ProductSaveIdle();
}

final class ProductSaveInProgress extends ProductSaveStatus {
  const ProductSaveInProgress();
}

final class ProductSaveSuccess extends ProductSaveStatus {
  final UpdatedProduct product;

  const ProductSaveSuccess(this.product);
}

final class ProductSaveFailure extends ProductSaveStatus {
  final String message;

  const ProductSaveFailure(this.message);
}

class EditProductState extends Equatable {
  static const nameMaxLength = 30;
  static final _letterPattern = RegExp(r'\p{L}', unicode: true);

  final PersistedProduct original;

  /// Raw text, as typed.
  final String name;
  final DateTime expirationDate;

  /// Null when the original type is unknown and the user hasn't picked one.
  final ProductType? productType;

  /// Raw text, as typed.
  final String amountText;

  /// Null when the product has no currency, or an unknown one, and the user
  /// hasn't picked one.
  final Currency? currency;
  final ProductSaveStatus saveStatus;

  const EditProductState({
    required this.original,
    required this.name,
    required this.expirationDate,
    required this.productType,
    required this.amountText,
    required this.currency,
    required this.saveStatus,
  });

  factory EditProductState.initial(PersistedProduct product) {
    return EditProductState(
      original: product,
      name: product.productName,
      expirationDate: product.expirationDate,
      productType: ProductType.tryParse(product.productType),
      amountText: _formatAmount(product.priceAmount),
      currency: Currency.tryParse(product.currency),
      saveStatus: const ProductSaveIdle(),
    );
  }

  bool get _hadPrice => original.priceAmount != null;

  String get _trimmedName => name.trim();

  String get _trimmedAmount => amountText.trim();

  /// Null when empty or not a finite positive number.
  double? get _parsedAmount {
    final value = double.tryParse(_trimmedAmount.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  bool get isSaving => saveStatus is ProductSaveInProgress;

  String? get nameError {
    if (_trimmedName.isEmpty) return 'Name is required.';
    if (_trimmedName.length > nameMaxLength) {
      return 'Name must be at most $nameMaxLength characters.';
    }
    if (!_letterPattern.hasMatch(_trimmedName)) {
      return 'Name must contain at least one letter.';
    }
    return null;
  }

  String? get amountError {
    if (_trimmedAmount.isEmpty) {
      // The API treats a missing amount as "unchanged", so a price can't be
      // cleared; a new price needs both amount and currency.
      if (_hadPrice) return "The price can't be removed.";
      if (currency != null) return 'Enter an amount.';
      return null;
    }
    if (_parsedAmount == null) return 'Enter an amount greater than 0.';
    return null;
  }

  String? get currencyError {
    if (!_hadPrice && _trimmedAmount.isNotEmpty && currency == null) {
      return 'Choose a currency.';
    }
    return null;
  }

  /// Only the fields whose value differs from [original].
  ProductChanges get changes {
    final amount = _parsedAmount;
    final date = _dateOnly(expirationDate);
    return ProductChanges(
      name: _trimmedName != original.productName ? _trimmedName : null,
      expirationDate: date != _dateOnly(original.expirationDate) ? date : null,
      productType: productType?.name != original.productType
          ? productType
          : null,
      amount: amount != original.priceAmount ? amount : null,
      currency: currency?.name != original.currency ? currency : null,
    );
  }

  bool get hasChanges => !changes.isEmpty;

  bool get canSave =>
      hasChanges &&
      nameError == null &&
      amountError == null &&
      currencyError == null &&
      !isSaving;

  EditProductState copyWith({
    String? name,
    DateTime? expirationDate,
    ProductType? productType,
    String? amountText,
    Currency? currency,
    ProductSaveStatus? saveStatus,
  }) {
    return EditProductState(
      original: original,
      name: name ?? this.name,
      expirationDate: expirationDate ?? this.expirationDate,
      productType: productType ?? this.productType,
      amountText: amountText ?? this.amountText,
      currency: currency ?? this.currency,
      saveStatus: saveStatus ?? this.saveStatus,
    );
  }

  @override
  List<Object?> get props => [
    original,
    name,
    expirationDate,
    productType,
    amountText,
    currency,
    saveStatus,
  ];
}

/// `2.5` → "2.5", `3.0` → "3", null → "".
String _formatAmount(double? amount) {
  if (amount == null) return '';
  if (amount == amount.truncateToDouble()) return amount.toInt().toString();
  return amount.toString();
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
