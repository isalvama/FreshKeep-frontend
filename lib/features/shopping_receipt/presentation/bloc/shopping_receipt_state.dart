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
  final ReceiptExtractionResult result;

  const ShoppingReceiptProcessSuccess(this.result);
}

final class ShoppingReceiptProcessFailure extends ShoppingReceiptStatus {
  final String message;

  const ShoppingReceiptProcessFailure(this.message);
}

class ShoppingReceiptState extends Equatable {
  final String? spaceId;
  final String? imagePath;
  final ShoppingReceiptStatus status;
  final Set<int> selectedForReprocess;

  const ShoppingReceiptState({
    required this.spaceId,
    required this.imagePath,
    required this.status,
    required this.selectedForReprocess,
  });

  factory ShoppingReceiptState.initial() {
    return const ShoppingReceiptState(
      spaceId: null,
      imagePath: null,
      status: ShoppingReceiptInitial(),
      selectedForReprocess: {},
    );
  }

  ShoppingReceiptState copyWith({
    String? spaceId,
    String? imagePath,
    ShoppingReceiptStatus? status,
    Set<int>? selectedForReprocess,
  }) {
    return ShoppingReceiptState(
      spaceId: spaceId ?? this.spaceId,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      selectedForReprocess: selectedForReprocess ?? this.selectedForReprocess,
    );
  }

  @override
  List<Object?> get props => [
    spaceId,
    imagePath,
    status,
    selectedForReprocess,
  ];
}
