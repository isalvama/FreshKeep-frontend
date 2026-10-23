import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shopping_receipt/domain/entities/persisted_product.dart';
import '../../domain/entities/currency.dart';
import '../../domain/entities/product_changes.dart';
import '../../domain/entities/product_type.dart';
import '../../domain/entities/updated_product.dart';
import '../../domain/usecases/update_product_usecase.dart';

part 'edit_product_event.dart';
part 'edit_product_state.dart';

class EditProductBloc extends Bloc<EditProductEvent, EditProductState> {
  final UpdateProductUseCase updateProductUseCase;

  EditProductBloc({
    required this.updateProductUseCase,
    required PersistedProduct product,
  }) : super(EditProductState.initial(product)) {
    on<EditProductNameChanged>(
      (event, emit) => _edit(emit, state.copyWith(name: event.name)),
    );
    on<EditProductExpirationDateChanged>(
      (event, emit) =>
          _edit(emit, state.copyWith(expirationDate: event.expirationDate)),
    );
    on<EditProductTypeChanged>(
      (event, emit) =>
          _edit(emit, state.copyWith(productType: event.productType)),
    );
    on<EditProductAmountChanged>(
      (event, emit) =>
          _edit(emit, state.copyWith(amountText: event.amountText)),
    );
    on<EditProductCurrencyChanged>(
      (event, emit) => _edit(emit, state.copyWith(currency: event.currency)),
    );
    on<EditProductSaveSubmitted>(_onSaveSubmitted);
  }

  /// Fields are locked while a save is in flight.
  void _edit(Emitter<EditProductState> emit, EditProductState next) {
    if (state.isSaving) return;
    emit(next);
  }

  Future<void> _onSaveSubmitted(
    EditProductSaveSubmitted event,
    Emitter<EditProductState> emit,
  ) async {
    if (!state.canSave) return;

    emit(state.copyWith(saveStatus: const ProductSaveInProgress()));

    final result = await updateProductUseCase(
      productId: state.original.id,
      changes: state.changes,
    );
    if (isClosed) return;

    result.match(
      (failure) =>
          emit(state.copyWith(saveStatus: ProductSaveFailure(failure.message))),
      (product) =>
          emit(state.copyWith(saveStatus: ProductSaveSuccess(product))),
    );
  }
}
