import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/persisted_shopping_receipt.dart';
import '../../domain/entities/receipt_extraction_result.dart';
import '../../domain/usecases/confirm_shopping_receipt_usecase.dart';
import '../../domain/usecases/process_new_shopping_receipt_usecase.dart';
import '../../domain/usecases/reprocess_shopping_receipt_usecase.dart';
import '../../domain/utils/expiration_date_shift.dart';

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
    on<ReceiptShoppingDateEdited>(_onShoppingDateEdited);
    on<ReceiptStoreNameEdited>(_onStoreNameEdited);
    on<ProductExpirationDateEdited>(_onProductExpirationDateEdited);
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
          flaggedIndices: _flaggedIndicesOf(extraction),
          shoppingDate: extraction.purchaseShoppingDate,
          storeName: extraction.storeName,
          editedExpirationDates: const {},
        ),
      ),
    );
  }

  /// Computed once, while products are still untouched: later edits change
  /// a product's equality, so the flagged group can't be found by `contains`.
  Set<int> _flaggedIndicesOf(ReceiptExtractionResult extraction) {
    final flagged = extraction.flaggedProducts.toSet();
    return {
      for (var i = 0; i < extraction.productExtractions.length; i++)
        if (flagged.contains(extraction.productExtractions[i])) i,
    };
  }

  void _onShoppingDateEdited(
    ReceiptShoppingDateEdited event,
    Emitter<ShoppingReceiptState> emit,
  ) {
    emit(state.copyWith(shoppingDate: _dateOnly(event.shoppingDate)));
  }

  void _onStoreNameEdited(
    ReceiptStoreNameEdited event,
    Emitter<ShoppingReceiptState> emit,
  ) {
    emit(state.copyWith(storeName: event.storeName));
  }

  /// Picking a product's original extracted date again removes its entry,
  /// so it no longer counts as manually edited.
  void _onProductExpirationDateEdited(
    ProductExpirationDateEdited event,
    Emitter<ShoppingReceiptState> emit,
  ) {
    final extraction = state.extraction;
    assert(
      extraction != null,
      'ProductExpirationDateEdited dispatched before an extraction was loaded.',
    );

    final chosen = _dateOnly(event.expirationDate);
    final original =
        extraction!.productExtractions[event.productIndex].expirationDate;
    final updated = Map<int, DateTime>.from(state.editedExpirationDates);
    if (chosen == _dateOnly(original)) {
      updated.remove(event.productIndex);
    } else {
      updated[event.productIndex] = chosen;
    }
    emit(state.copyWith(editedExpirationDates: updated));
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

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

    // Unedited products keep their ORIGINAL extracted date (flag false) so
    // the backend applies its own shopping-date shift exactly once; edited
    // products carry the chosen date with the flag set.
    final allProducts = [
      for (var i = 0; i < extraction!.productExtractions.length; i++)
        if (state.editedExpirationDates[i] case final edited?)
          extraction.productExtractions[i].copyWith(
            expirationDate: edited,
            manuallyEditedExpirationDate: true,
          )
        else
          extraction.productExtractions[i],
    ];

    emit(state.copyWith(status: const ShoppingReceiptConfirming()));

    final result = await confirmShoppingReceiptUseCase(
      spaceId: spaceId!,
      shoppingReceiptId: extraction.shoppingReceiptId,
      receiptImageId: extraction.receiptImageId,
      shoppingDate: state.shoppingDate ?? extraction.purchaseShoppingDate,
      storeName: state.storeName ?? extraction.storeName,
      allProducts: allProducts,
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

    // Reprocess never carries edits (the backend would re-shift them), so
    // pending edits are discarded here, before the request goes out.
    emit(
      state.copyWith(
        status: const ShoppingReceiptReprocessing(),
        shoppingDate: extraction!.purchaseShoppingDate,
        storeName: extraction.storeName,
        editedExpirationDates: const {},
      ),
    );

    final language =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;

    final result = await reprocessShoppingReceiptUseCase(
      spaceId: spaceId!,
      shoppingReceiptId: extraction.shoppingReceiptId,
      receiptImageId: extraction.receiptImageId,
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
