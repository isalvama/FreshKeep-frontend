import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/receipt_extraction_result.dart';
import '../../domain/usecases/process_new_shopping_receipt_usecase.dart';

part 'shopping_receipt_event.dart';
part 'shopping_receipt_state.dart';

class ShoppingReceiptBloc
    extends Bloc<ShoppingReceiptEvent, ShoppingReceiptState> {
  final ProcessNewShoppingReceiptUseCase processNewShoppingReceiptUseCase;

  ShoppingReceiptBloc({required this.processNewShoppingReceiptUseCase})
    : super(ShoppingReceiptState.initial()) {
    on<ShoppingReceiptFlowReset>(_onFlowReset);
    on<SpaceForReceiptSelected>(_onSpaceSelected);
    on<ReceiptImagePicked>(_onImagePicked);
    on<ReceiptProcessingSubmitted>(_onProcessingSubmitted);
    on<ReprocessSelectionToggled>(_onReprocessSelectionToggled);
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
        state.copyWith(status: ShoppingReceiptProcessSuccess(extraction)),
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
}
