part of 'shopping_receipt_bloc.dart';

sealed class ShoppingReceiptStatus {
  const ShoppingReceiptStatus();
}

final class ShoppingReceiptInitial extends ShoppingReceiptStatus {
  const ShoppingReceiptInitial();
}

final class ShoppingReceiptProcessing extends ShoppingReceiptStatus {
  const ShoppingReceiptProcessing();
}

final class ShoppingReceiptProcessSuccess extends ShoppingReceiptStatus {
  const ShoppingReceiptProcessSuccess();
}

final class ShoppingReceiptProcessFailure extends ShoppingReceiptStatus {
  final String message;

  const ShoppingReceiptProcessFailure(this.message);
}

final class ShoppingReceiptConfirming extends ShoppingReceiptStatus {
  const ShoppingReceiptConfirming();
}

final class ShoppingReceiptConfirmSuccess extends ShoppingReceiptStatus {
  const ShoppingReceiptConfirmSuccess();
}

final class ShoppingReceiptConfirmFailure extends ShoppingReceiptStatus {
  final String message;

  const ShoppingReceiptConfirmFailure(this.message);
}

final class ShoppingReceiptReprocessing extends ShoppingReceiptStatus {
  const ShoppingReceiptReprocessing();
}

final class ShoppingReceiptReprocessSuccess extends ShoppingReceiptStatus {
  const ShoppingReceiptReprocessSuccess();
}

final class ShoppingReceiptReprocessFailure extends ShoppingReceiptStatus {
  final String message;

  const ShoppingReceiptReprocessFailure(this.message);
}

class ShoppingReceiptState extends Equatable {
  final String? spaceId;
  final String? imagePath;
  final ShoppingReceiptStatus status;
  final ReceiptExtractionResult? extraction;
  final PersistedShoppingReceipt? reprocessedReceipt;
  final Set<int> selectedForReprocess;
  final int consecutiveFailureCount;

  const ShoppingReceiptState({
    required this.spaceId,
    required this.imagePath,
    required this.status,
    required this.extraction,
    required this.reprocessedReceipt,
    required this.selectedForReprocess,
    required this.consecutiveFailureCount,
  });

  factory ShoppingReceiptState.initial() {
    return const ShoppingReceiptState(
      spaceId: null,
      imagePath: null,
      status: ShoppingReceiptInitial(),
      extraction: null,
      reprocessedReceipt: null,
      selectedForReprocess: {},
      consecutiveFailureCount: 0,
    );
  }

  ShoppingReceiptState copyWith({
    String? spaceId,
    String? imagePath,
    ShoppingReceiptStatus? status,
    ReceiptExtractionResult? extraction,
    PersistedShoppingReceipt? reprocessedReceipt,
    Set<int>? selectedForReprocess,
    int? consecutiveFailureCount,
  }) {
    return ShoppingReceiptState(
      spaceId: spaceId ?? this.spaceId,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      extraction: extraction ?? this.extraction,
      reprocessedReceipt: reprocessedReceipt ?? this.reprocessedReceipt,
      selectedForReprocess: selectedForReprocess ?? this.selectedForReprocess,
      consecutiveFailureCount:
          consecutiveFailureCount ?? this.consecutiveFailureCount,
    );
  }

  @override
  List<Object?> get props => [
    spaceId,
    imagePath,
    status,
    extraction,
    reprocessedReceipt,
    selectedForReprocess,
    consecutiveFailureCount,
  ];
}
