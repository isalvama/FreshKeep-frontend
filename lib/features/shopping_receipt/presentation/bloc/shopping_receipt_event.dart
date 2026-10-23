part of 'shopping_receipt_bloc.dart';

sealed class ShoppingReceiptEvent {
  const ShoppingReceiptEvent();
}

final class ShoppingReceiptFlowReset extends ShoppingReceiptEvent {
  const ShoppingReceiptFlowReset();
}

final class SpaceForReceiptSelected extends ShoppingReceiptEvent {
  final String spaceId;

  const SpaceForReceiptSelected(this.spaceId);
}

final class ReceiptImagePicked extends ShoppingReceiptEvent {
  final String imagePath;

  const ReceiptImagePicked(this.imagePath);
}

final class ReceiptProcessingSubmitted extends ShoppingReceiptEvent {
  const ReceiptProcessingSubmitted();
}

final class ReprocessSelectionToggled extends ShoppingReceiptEvent {
  final int productIndex;

  const ReprocessSelectionToggled(this.productIndex);
}

final class ReceiptConfirmSubmitted extends ShoppingReceiptEvent {
  const ReceiptConfirmSubmitted();
}

final class ReceiptReprocessSubmitted extends ShoppingReceiptEvent {
  const ReceiptReprocessSubmitted();
}

final class ReceiptShoppingDateEdited extends ShoppingReceiptEvent {
  final DateTime shoppingDate;

  const ReceiptShoppingDateEdited(this.shoppingDate);
}

/// [storeName] is expected already trimmed and non-blank.
final class ReceiptStoreNameEdited extends ShoppingReceiptEvent {
  final String storeName;

  const ReceiptStoreNameEdited(this.storeName);
}

final class ProductExpirationDateEdited extends ShoppingReceiptEvent {
  final int productIndex;
  final DateTime expirationDate;

  const ProductExpirationDateEdited(this.productIndex, this.expirationDate);
}
