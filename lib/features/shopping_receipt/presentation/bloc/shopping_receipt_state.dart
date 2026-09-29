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

  /// Indices into `extraction.productExtractions` of the AI-flagged products,
  /// computed once on process success.
  final Set<int> flaggedIndices;

  /// Current (possibly edited) shopping date; seeded from the extraction.
  final DateTime? shoppingDate;

  /// Current (possibly edited) store name; seeded from the extraction.
  final String? storeName;

  /// productIndex → user-chosen expiration date. An entry exists only while
  /// it differs from the product's originally extracted date.
  final Map<int, DateTime> editedExpirationDates;

  const ShoppingReceiptState({
    required this.spaceId,
    required this.imagePath,
    required this.status,
    required this.extraction,
    required this.reprocessedReceipt,
    required this.selectedForReprocess,
    required this.consecutiveFailureCount,
    required this.flaggedIndices,
    required this.shoppingDate,
    required this.storeName,
    required this.editedExpirationDates,
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
      flaggedIndices: {},
      shoppingDate: null,
      storeName: null,
      editedExpirationDates: {},
    );
  }

  bool get hasPendingEdits {
    final extraction = this.extraction;
    if (extraction == null) return false;
    return shoppingDate != extraction.purchaseShoppingDate ||
        storeName != extraction.storeName ||
        editedExpirationDates.isNotEmpty;
  }

  /// The expiration date shown for product [index]: the user-chosen date if
  /// edited, otherwise the extracted date shifted by any shopping-date edit.
  DateTime displayedExpirationDate(int index) {
    final extraction = this.extraction!;
    final edited = editedExpirationDates[index];
    if (edited != null) return edited;
    return shiftExpirationDate(
      original: extraction.productExtractions[index].expirationDate,
      fromShoppingDate: extraction.purchaseShoppingDate,
      toShoppingDate: shoppingDate ?? extraction.purchaseShoppingDate,
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
    Set<int>? flaggedIndices,
    DateTime? shoppingDate,
    String? storeName,
    Map<int, DateTime>? editedExpirationDates,
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
      flaggedIndices: flaggedIndices ?? this.flaggedIndices,
      shoppingDate: shoppingDate ?? this.shoppingDate,
      storeName: storeName ?? this.storeName,
      editedExpirationDates:
          editedExpirationDates ?? this.editedExpirationDates,
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
    flaggedIndices,
    shoppingDate,
    storeName,
    editedExpirationDates,
  ];
}
