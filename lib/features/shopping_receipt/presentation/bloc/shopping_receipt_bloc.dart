import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/persisted_shopping_receipt.dart';
import '../../domain/entities/receipt_extraction_result.dart';
import '../../domain/usecases/confirm_shopping_receipt_usecase.dart';
import '../../domain/usecases/process_new_shopping_receipt_usecase.dart';
import '../../domain/usecases/reprocess_shopping_receipt_usecase.dart';

part 'shopping_receipt_event.dart';
part 'shopping_receipt_state.dart';

class ShoppingReceiptBloc
    extends Bloc<ShoppingReceiptEvent, ShoppingReceiptState> {
  final ProcessNewShoppingReceiptUseCase processNewShoppingReceiptUseCase;
  final ConfirmShoppingReceiptUseCase confirmShoppingReceiptUseCase;
  final ReprocessShoppingReceiptUseCase reprocessShoppingReceiptUseCase;

  ShoppingReceiptBloc({
    required this.processNewShoppingReceiptUseCase,
    required this.confirmShoppingReceiptUseCase,
    required this.reprocessShoppingReceiptUseCase,
  }) : super(ShoppingReceiptState.initial()) {
    on<ShoppingReceiptFlowReset>(_onFlowReset);
    on<SpaceForReceiptSelected>(_onSpaceSelected);
    on<ReceiptImagePicked>(_onImagePicked);
    on<ReceiptProcessingSubmitted>(_onProcessingSubmitted);
    on<ReprocessSelectionToggled>(_onReprocessSelectionToggled);
    on<ReceiptConfirmSubmitted>(_onConfirmSubmitted);
    on<ReceiptReprocessSubmitted>(_onReprocessSubmitted);
  }

  void _onFlowReset(
    ShoppingReceiptFlowReset event,
    Emitter<ShoppingReceiptState> emit,
  ) {
    emit(ShoppingReceiptState.initial());
  }

  void _onSpaceSelected(
    SpaceForReceiptSelected event,
    Emitter<ShoppingReceiptState> emit,
  ) {
    emit(state.copyWith(spaceId: event.spaceId));
  }

  void _onImagePicked(
    ReceiptImagePicked event,
    Emitter<ShoppingReceiptState> emit,
  ) {
    emit(state.copyWith(imagePath: event.imagePath));
  }

  Future<void> _onProcessingSubmitted(
    ReceiptProcessingSubmitted event,
    Emitter<ShoppingReceiptState> emit,
  ) async {
    final spaceId = state.spaceId;
    final imagePath = state.imagePath;
    assert(
      spaceId != null && imagePath != null,
      'ReceiptProcessingSubmitted dispatched before a space and image were selected.',
    );

    emit(state.copyWith(status: const ShoppingReceiptProcessing()));

    final language =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;

    final result = await processNewShoppingReceiptUseCase(
      spaceId: spaceId!,
      imagePath: imagePath!,
      language: language,
    );

    result.match(
      (failure) => emit(
        state.copyWith(status: ShoppingReceiptProcessFailure(failure.message)),
      ),
      (extraction) => emit(
        state.copyWith(
          status: const ShoppingReceiptProcessSuccess(),
          extraction: extraction,
        ),
      ),
    );
  }

  void _onReprocessSelectionToggled(
    ReprocessSelectionToggled event,
    Emitter<ShoppingReceiptState> emit,
  ) {
    final updated = Set<int>.from(state.selectedForReprocess);
    if (!updated.remove(event.productIndex)) {
      updated.add(event.productIndex);
    }
    emit(state.copyWith(selectedForReprocess: updated));
  }

  Future<void> _onConfirmSubmitted(
    ReceiptConfirmSubmitted event,
    Emitter<ShoppingReceiptState> emit,
  ) async {
    if (state.status is ShoppingReceiptConfirming ||
        state.status is ShoppingReceiptReprocessing) {
      return;
    }

    final spaceId = state.spaceId;
    final extraction = state.extraction;
    assert(
      spaceId != null && extraction != null,
      'ReceiptConfirmSubmitted dispatched before an extraction was loaded.',
    );

    emit(state.copyWith(status: const ShoppingReceiptConfirming()));

    final result = await confirmShoppingReceiptUseCase(
      spaceId: spaceId!,
      receiptImageId: extraction!.receiptImageId,
      shoppingDate: extraction.purchaseShoppingDate,
      storeName: extraction.storeName,
      allProducts: extraction.productExtractions,
      spaceStorageSpots: extraction.suggestedStorageSpots,
    );

    result.match(
      (failure) => emit(
        state.copyWith(
          status: ShoppingReceiptConfirmFailure(failure.message),
          consecutiveFailureCount: state.consecutiveFailureCount + 1,
        ),
      ),
      (_) => emit(
        state.copyWith(
          status: const ShoppingReceiptConfirmSuccess(),
          consecutiveFailureCount: 0,
        ),
      ),
    );
  }

  Future<void> _onReprocessSubmitted(
    ReceiptReprocessSubmitted event,
    Emitter<ShoppingReceiptState> emit,
  ) async {
    if (state.status is ShoppingReceiptConfirming ||
        state.status is ShoppingReceiptReprocessing) {
      return;
    }

    final spaceId = state.spaceId;
    final extraction = state.extraction;
    assert(
      spaceId != null && extraction != null,
      'ReceiptReprocessSubmitted dispatched before an extraction was loaded.',
    );
    assert(
      state.selectedForReprocess.isNotEmpty,
      'ReceiptReprocessSubmitted dispatched with no products selected.',
    );

    final flaggedProducts = state.selectedForReprocess
        .map((index) => extraction!.productExtractions[index])
        .toList();

    emit(state.copyWith(status: const ShoppingReceiptReprocessing()));

    final language =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;

    final result = await reprocessShoppingReceiptUseCase(
      spaceId: spaceId!,
      receiptImageId: extraction!.receiptImageId,
      shoppingDate: extraction.purchaseShoppingDate,
      storeName: extraction.storeName,
      language: language,
      flaggedProducts: flaggedProducts,
      allProducts: extraction.productExtractions,
      spaceStorageSpots: extraction.suggestedStorageSpots,
    );

    result.match(
      (failure) => emit(
        state.copyWith(
          status: ShoppingReceiptReprocessFailure(failure.message),
          consecutiveFailureCount: state.consecutiveFailureCount + 1,
        ),
      ),
      (persisted) => emit(
        state.copyWith(
          status: const ShoppingReceiptReprocessSuccess(),
          reprocessedReceipt: persisted,
          consecutiveFailureCount: 0,
        ),
      ),
    );
  }
}
