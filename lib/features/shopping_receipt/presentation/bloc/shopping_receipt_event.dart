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
