import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/currency.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/moved_product.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/product_changes.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/product_type.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/updated_product.dart';
import 'package:fresh_keep_frontend/features/products/domain/repositories/product_repository.dart';
import 'package:fresh_keep_frontend/features/products/domain/usecases/update_product_usecase.dart';
import 'package:fresh_keep_frontend/features/products/presentation/bloc/edit_product_bloc.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/persisted_product.dart';

/// Records every update call. Each call resolves with [result], or waits on
/// [pending] when it is set.
class _RecordingProductRepository implements ProductRepository {
  _RecordingProductRepository({required this.result});

  Either<ProductFailure, UpdatedProduct> result;
  Completer<Either<ProductFailure, UpdatedProduct>>? pending;
  final List<(String, ProductChanges)> updateCalls = [];

  @override
  Future<Either<ProductFailure, UpdatedProduct>> updateProduct({
    required String productId,
    required ProductChanges changes,
  }) async {
    updateCalls.add((productId, changes));
    return pending != null ? pending!.future : result;
  }

  @override
  Future<Either<ProductFailure, Unit>> deleteProduct({
    required String productId,
  }) => throw UnimplementedError();

  @override
  Future<Either<ProductFailure, Unit>> deleteProducts({
    required List<String> productIds,
  }) => throw UnimplementedError();

  @override
  Future<Either<ProductFailure, MovedProduct>> moveProduct({
    required String productId,
    required String oldStorageSpotId,
    required String newStorageSpotId,
  }) => throw UnimplementedError();
}

final _milk = PersistedProduct(
  id: 'p1',
  productName: 'Milk',
  expirationDate: DateTime(2026, 10, 1),
  storageSpotId: 'spot-1',
  productType: 'DAIRY',
  priceAmount: 2.5,
  currency: 'EUR',
);

final _bread = PersistedProduct(
  id: 'p2',
  productName: 'Bread',
  expirationDate: DateTime(2026, 10, 2),
  storageSpotId: null,
  productType: 'BAKERY',
  priceAmount: null,
  currency: null,
);

final _updated = UpdatedProduct(
  productId: 'p1',
  name: 'Oat milk',
  expirationDate: DateTime(2026, 10, 1),
  productType: 'DAIRY',
  amount: 2.5,
  currency: 'EUR',
);

EditProductBloc _buildBloc(
  PersistedProduct product, {
  _RecordingProductRepository? repository,
}) {
  return EditProductBloc(
    updateProductUseCase: UpdateProductUseCase(
      repository ?? _RecordingProductRepository(result: Right(_updated)),
    ),
    product: product,
  );
}

/// Lets queued events be handled and the stubbed use case resolve.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<EditProductState> _stateAfter(
  PersistedProduct product,
  List<EditProductEvent> events,
) async {
  final bloc = _buildBloc(product);
  events.forEach(bloc.add);
  await _settle();
  final state = bloc.state;
  await bloc.close();
  return state;
}

void main() {
  group('initial state', () {
    test('is pre-filled from a product with a price', () {
      final state = _buildBloc(_milk).state;

      expect(state.name, 'Milk');
      expect(state.expirationDate, DateTime(2026, 10, 1));
      expect(state.productType, ProductType.DAIRY);
      expect(state.amountText, '2.5');
      expect(state.currency, Currency.EUR);
      expect(state.saveStatus, isA<ProductSaveIdle>());
      expect(state.hasChanges, isFalse);
      expect(state.canSave, isFalse);
    });

    test('drops a trailing .0 from the amount', () {
      final product = PersistedProduct(
        id: 'p1',
        productName: 'Milk',
        expirationDate: DateTime(2026, 10, 1),
        storageSpotId: null,
        productType: 'DAIRY',
        priceAmount: 3.0,
        currency: 'EUR',
      );

      expect(_buildBloc(product).state.amountText, '3');
    });

    test('has an empty amount and no currency for a product without a '
        'price', () {
      final state = _buildBloc(_bread).state;

      expect(state.amountText, '');
      expect(state.currency, isNull);
      expect(state.amountError, isNull);
      expect(state.currencyError, isNull);
    });

    test('leaves an unknown type or currency unselected and unchanged', () {
      final product = PersistedProduct(
        id: 'p1',
        productName: 'Tofu',
        expirationDate: DateTime(2026, 10, 1),
        storageSpotId: null,
        productType: 'CANNED',
        priceAmount: 1.0,
        currency: 'XYZ',
      );
      final state = _buildBloc(product).state;

      expect(state.productType, isNull);
      expect(state.currency, isNull);
      expect(state.changes.isEmpty, isTrue);
      expect(state.amountError, isNull);
      expect(state.currencyError, isNull);
    });
  });

  group('validation', () {
    test('an empty or blank name is required', () async {
      final state = await _stateAfter(_milk, [
        const EditProductNameChanged('   '),
      ]);

      expect(state.nameError, 'Name is required.');
      expect(state.canSave, isFalse);
    });

    test('a name longer than 30 characters after trimming is rejected; 30 is '
        'fine', () async {
      final tooLong = await _stateAfter(_milk, [
        EditProductNameChanged('a' * 31),
      ]);
      final atLimit = await _stateAfter(_milk, [
        EditProductNameChanged('  ${'a' * 30}  '),
      ]);

      expect(tooLong.nameError, 'Name must be at most 30 characters.');
      expect(atLimit.nameError, isNull);
      expect(atLimit.canSave, isTrue);
    });

    for (final text in ['123', '-- 4 --', '🥛']) {
      test('a name without a letter ("$text") is rejected', () async {
        final state = await _stateAfter(_milk, [EditProductNameChanged(text)]);

        expect(state.nameError, 'Name must contain at least one letter.');
        expect(state.canSave, isFalse);
      });
    }

    test('a name with any letter, including accented ones, is fine', () async {
      final state = await _stateAfter(_milk, [
        const EditProductNameChanged('7 Ñoquis'),
      ]);

      expect(state.nameError, isNull);
      expect(state.canSave, isTrue);
    });

    for (final text in ['abc', '0', '-1', '0,0']) {
      test('amount "$text" is rejected', () async {
        final state = await _stateAfter(_milk, [
          EditProductAmountChanged(text),
        ]);

        expect(state.amountError, 'Enter an amount greater than 0.');
        expect(state.canSave, isFalse);
      });
    }

    test('emptying the amount of a product with a price is rejected', () async {
      final state = await _stateAfter(_milk, [
        const EditProductAmountChanged(''),
      ]);

      expect(state.amountError, "The price can't be removed.");
      expect(state.canSave, isFalse);
    });

    group('a product without a price', () {
      test('an amount without a currency asks for a currency', () async {
        final state = await _stateAfter(_bread, [
          const EditProductAmountChanged('1.2'),
        ]);

        expect(state.currencyError, 'Choose a currency.');
        expect(state.amountError, isNull);
        expect(state.canSave, isFalse);
      });

      test('a currency without an amount asks for an amount', () async {
        final state = await _stateAfter(_bread, [
          const EditProductCurrencyChanged(Currency.USD),
        ]);

        expect(state.amountError, 'Enter an amount.');
        expect(state.currencyError, isNull);
        expect(state.canSave, isFalse);
      });

      test('both set is valid and both are changes', () async {
        final state = await _stateAfter(_bread, [
          const EditProductAmountChanged('1,2'),
          const EditProductCurrencyChanged(Currency.USD),
        ]);

        expect(state.amountError, isNull);
        expect(state.currencyError, isNull);
        expect(
          state.changes,
          const ProductChanges(amount: 1.2, currency: Currency.USD),
        );
        expect(state.canSave, isTrue);
      });

      test('both empty is valid', () async {
        final state = await _stateAfter(_bread, [
          const EditProductNameChanged('Rye bread'),
        ]);

        expect(state.amountError, isNull);
        expect(state.currencyError, isNull);
        expect(state.canSave, isTrue);
      });
    });
  });

  group('changes', () {
    test('contain only the fields that differ from the original', () async {
      final state = await _stateAfter(_milk, [
        const EditProductNameChanged('  Oat milk '),
        EditProductExpirationDateChanged(DateTime(2026, 10, 7)),
        const EditProductTypeChanged(ProductType.OTHER_FRESH_PRODUCTS),
        const EditProductAmountChanged('3,75'),
        const EditProductCurrencyChanged(Currency.USD),
      ]);

      expect(
        state.changes,
        ProductChanges(
          name: 'Oat milk',
          expirationDate: DateTime(2026, 10, 7),
          productType: ProductType.OTHER_FRESH_PRODUCTS,
          amount: 3.75,
          currency: Currency.USD,
        ),
      );
    });

    test('values equal to the original are not changes', () async {
      final state = await _stateAfter(_milk, [
        const EditProductNameChanged('  Milk  '),
        EditProductExpirationDateChanged(DateTime(2026, 10, 1, 15, 30)),
        const EditProductTypeChanged(ProductType.DAIRY),
        const EditProductAmountChanged('2,50'),
        const EditProductCurrencyChanged(Currency.EUR),
      ]);

      expect(state.changes.isEmpty, isTrue);
      expect(state.hasChanges, isFalse);
      expect(state.canSave, isFalse);
    });

    test('"3" and "3.0" equal an original price of 3.0', () async {
      final product = PersistedProduct(
        id: 'p1',
        productName: 'Milk',
        expirationDate: DateTime(2026, 10, 1),
        storageSpotId: null,
        productType: 'DAIRY',
        priceAmount: 3.0,
        currency: 'EUR',
      );

      for (final text in ['3', '3.0', '3,00']) {
        final state = await _stateAfter(product, [
          EditProductAmountChanged(text),
        ]);
        expect(state.changes.isEmpty, isTrue, reason: text);
      }
    });

    test('the date change drops the time of day', () async {
      final state = await _stateAfter(_milk, [
        EditProductExpirationDateChanged(DateTime(2026, 10, 9, 18)),
      ]);

      expect(state.changes.expirationDate, DateTime(2026, 10, 9));
    });
  });

  group('EditProductSaveSubmitted', () {
    test('is ignored while there are no changes', () async {
      final repository = _RecordingProductRepository(result: Right(_updated));
      final bloc = _buildBloc(_milk, repository: repository);

      bloc.add(const EditProductSaveSubmitted());
      await _settle();

      expect(repository.updateCalls, isEmpty);
      expect(bloc.state.saveStatus, isA<ProductSaveIdle>());
      await bloc.close();
    });

    test('is ignored while a field is invalid', () async {
      final repository = _RecordingProductRepository(result: Right(_updated));
      final bloc = _buildBloc(_milk, repository: repository);

      bloc
        ..add(const EditProductNameChanged(''))
        ..add(const EditProductSaveSubmitted());
      await _settle();

      expect(repository.updateCalls, isEmpty);
      await bloc.close();
    });

    test('sends only the changes and emits InProgress then Success', () async {
      final repository = _RecordingProductRepository(result: Right(_updated));
      final bloc = _buildBloc(_milk, repository: repository);
      final statuses = <ProductSaveStatus>[];
      final subscription = bloc.stream.listen(
        (s) => statuses.add(s.saveStatus),
      );

      bloc
        ..add(const EditProductNameChanged('Oat milk'))
        ..add(const EditProductSaveSubmitted());
      await _settle();

      expect(repository.updateCalls, [
        ('p1', const ProductChanges(name: 'Oat milk')),
      ]);
      expect(statuses.skip(1).toList(), [
        isA<ProductSaveInProgress>(),
        isA<ProductSaveSuccess>().having((s) => s.product, 'product', _updated),
      ]);

      await subscription.cancel();
      await bloc.close();
    });

    test(
      'on failure emits Failure, keeps the edits, and can be retried',
      () async {
        final repository = _RecordingProductRepository(
          result: const Left(ProductValidationFailure('Bad name')),
        );
        final bloc = _buildBloc(_milk, repository: repository);

        bloc
          ..add(const EditProductNameChanged('Oat milk'))
          ..add(const EditProductSaveSubmitted());
        await _settle();

        expect(
          bloc.state.saveStatus,
          isA<ProductSaveFailure>().having(
            (s) => s.message,
            'message',
            'Bad name',
          ),
        );
        expect(bloc.state.name, 'Oat milk');
        expect(bloc.state.canSave, isTrue);

        repository.result = Right(_updated);
        bloc.add(const EditProductSaveSubmitted());
        await _settle();

        expect(repository.updateCalls, hasLength(2));
        expect(bloc.state.saveStatus, isA<ProductSaveSuccess>());
        await bloc.close();
      },
    );

    test('field events and a second submit are ignored while saving', () async {
      final repository = _RecordingProductRepository(result: Right(_updated))
        ..pending = Completer();
      final bloc = _buildBloc(_milk, repository: repository);

      bloc
        ..add(const EditProductNameChanged('Oat milk'))
        ..add(const EditProductSaveSubmitted());
      await _settle();
      expect(bloc.state.saveStatus, isA<ProductSaveInProgress>());
      expect(bloc.state.canSave, isFalse);

      bloc
        ..add(const EditProductNameChanged('Soy milk'))
        ..add(EditProductExpirationDateChanged(DateTime(2027)))
        ..add(const EditProductTypeChanged(ProductType.OTHER))
        ..add(const EditProductAmountChanged('9'))
        ..add(const EditProductCurrencyChanged(Currency.USD))
        ..add(const EditProductSaveSubmitted());
      await _settle();

      expect(bloc.state.name, 'Oat milk');
      expect(bloc.state.expirationDate, DateTime(2026, 10, 1));
      expect(bloc.state.productType, ProductType.DAIRY);
      expect(bloc.state.amountText, '2.5');
      expect(bloc.state.currency, Currency.EUR);
      expect(repository.updateCalls, hasLength(1));

      repository.pending!.complete(Right(_updated));
      await _settle();
      expect(bloc.state.saveStatus, isA<ProductSaveSuccess>());
      await bloc.close();
    });
  });
}
