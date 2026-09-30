import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/moved_product.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/product_changes.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/product_type.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/updated_product.dart';
import 'package:fresh_keep_frontend/features/products/domain/repositories/product_repository.dart';
import 'package:fresh_keep_frontend/features/products/domain/usecases/update_product_usecase.dart';
import 'package:fresh_keep_frontend/features/products/presentation/bloc/edit_product_bloc.dart';
import 'package:fresh_keep_frontend/features/products/presentation/pages/edit_product_page.dart';
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

final _updated = UpdatedProduct(
  productId: 'p1',
  name: 'Oat milk',
  expirationDate: DateTime(2026, 10, 1),
  productType: 'OTHER_FRESH_PRODUCTS',
  amount: 2.5,
  currency: 'EUR',
);

/// What the page popped with, as seen by the page that pushed it.
class _Result {
  bool returned = false;
  UpdatedProduct? product;
}

/// Pushes the edit page from a launcher page, like the overview does, and
/// records what it pops with.
Future<_Result> _open(
  WidgetTester tester, {
  PersistedProduct? product,
  _RecordingProductRepository? repository,
}) async {
  final result = _Result();
  final products =
      repository ?? _RecordingProductRepository(result: Right(_updated));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result.product = await context.push<UpdatedProduct>(
                  '/edit',
                  extra: product ?? _milk,
                );
                result.returned = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/edit',
        builder: (context, state) => BlocProvider(
          create: (_) => EditProductBloc(
            updateProductUseCase: UpdateProductUseCase(products),
            product: state.extra as PersistedProduct,
          ),
          child: const EditProductPage(),
        ),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

Finder get _saveButton => find.widgetWithText(TextButton, 'Save');

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<TextButton>(_saveButton).onPressed != null;

Finder get _nameField => find.byKey(const Key('edit_product_name'));
Finder get _amountField => find.byKey(const Key('edit_product_amount'));

Future<void> _enter(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _pickFromDropdown(
  WidgetTester tester,
  String dropdownKey,
  String item,
) async {
  await tester.tap(find.byKey(Key(dropdownKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Future<void> _tapClose(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Close'));
  await tester.pumpAndSettle();
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('form', () {
    testWidgets('is pre-filled from the product', (tester) async {
      await _open(tester);

      expect(find.text('Edit product'), findsOneWidget);
      expect(tester.widget<TextField>(_nameField).controller!.text, 'Milk');
      expect(find.text('2026-10-01'), findsOneWidget);
      expect(find.text('Dairy'), findsOneWidget);
      expect(tester.widget<TextField>(_amountField).controller!.text, '2.5');
      expect(find.text('EUR — Euro (€)'), findsOneWidget);
    });

    testWidgets('shows "Unknown (VALUE)" for an unknown type or currency', (
      tester,
    ) async {
      await _open(
        tester,
        product: PersistedProduct(
          id: 'p1',
          productName: 'Tofu',
          expirationDate: DateTime(2026, 10, 1),
          storageSpotId: null,
          productType: 'CANNED',
          priceAmount: 1.0,
          currency: 'XYZ',
        ),
      );

      expect(find.text('Unknown (CANNED)'), findsOneWidget);
      expect(find.text('Unknown (XYZ)'), findsOneWidget);
    });

    testWidgets('the type dropdown lists the 17 types by label', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.byKey(const Key('edit_product_type')));
      await tester.pumpAndSettle();

      expect(
        find.byType(DropdownMenuItem<ProductType>, skipOffstage: false),
        // The menu's items plus the button's own copies of each item.
        findsNWidgets(ProductType.values.length * 2),
      );
      expect(find.text('Other fresh products').last, findsOneWidget);
    });

    testWidgets('the date picker allows past dates and updates the field', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.byKey(const Key('edit_product_expiration_date')));
      await tester.pumpAndSettle();

      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate.isBefore(DateTime.now()), isTrue);

      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('2026-10-15'), findsOneWidget);
      expect(_saveEnabled(tester), isTrue);
    });
  });

  group('validation', () {
    testWidgets('Save is disabled until something changes', (tester) async {
      await _open(tester);

      expect(_saveEnabled(tester), isFalse);

      await _enter(tester, _nameField, 'Oat milk');
      expect(_saveEnabled(tester), isTrue);

      await _enter(tester, _nameField, 'Milk');
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('invalid fields show inline errors and disable Save', (
      tester,
    ) async {
      await _open(tester);

      await _enter(tester, _nameField, '  ');
      expect(find.text('Name is required.'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);

      await _enter(tester, _nameField, 'Oat milk');
      await _enter(tester, _amountField, '0');
      expect(find.text('Enter an amount greater than 0.'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);

      await _enter(tester, _amountField, '');
      expect(find.text("The price can't be removed."), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('a new price asks for a currency', (tester) async {
      await _open(
        tester,
        product: PersistedProduct(
          id: 'p2',
          productName: 'Bread',
          expirationDate: DateTime(2026, 10, 2),
          storageSpotId: null,
          productType: 'BAKERY',
          priceAmount: null,
          currency: null,
        ),
      );

      await _enter(tester, _amountField, '1,2');

      expect(find.text('Choose a currency.'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
    });
  });

  group('saving', () {
    testWidgets('sends only the changed fields and pops with the result', (
      tester,
    ) async {
      final repository = _RecordingProductRepository(result: Right(_updated));
      final result = await _open(tester, repository: repository);

      await _enter(tester, _nameField, '  Oat milk ');
      await _pickFromDropdown(
        tester,
        'edit_product_type',
        'Other fresh products',
      );
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(repository.updateCalls, [
        (
          'p1',
          const ProductChanges(
            name: 'Oat milk',
            productType: ProductType.OTHER_FRESH_PRODUCTS,
          ),
        ),
      ]);
      expect(result.returned, isTrue);
      expect(result.product, _updated);
      expect(find.text('Edit product'), findsNothing);
    });

    testWidgets('while saving, a spinner replaces Save, fields are disabled '
        'and close/back do nothing', (tester) async {
      final repository = _RecordingProductRepository(result: Right(_updated))
        ..pending = Completer();
      final result = await _open(tester, repository: repository);

      await _enter(tester, _nameField, 'Oat milk');
      await tester.tap(_saveButton);
      await tester.pump();

      expect(_saveButton, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<TextField>(_nameField).enabled, isFalse);
      expect(tester.widget<TextField>(_amountField).enabled, isFalse);
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close))
            .onPressed,
        isNull,
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Edit product'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      expect(result.returned, isFalse);

      repository.pending!.complete(Right(_updated));
      await tester.pumpAndSettle();
      expect(result.product, _updated);
    });

    testWidgets('on failure, stays with the edits kept, shows the message, '
        'and can retry', (tester) async {
      final repository = _RecordingProductRepository(
        result: const Left(ProductValidationFailure('Name is invalid.')),
      );
      final result = await _open(tester, repository: repository);

      await _enter(tester, _nameField, 'Oat milk');
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Name is invalid.'), findsOneWidget);
      expect(find.text('Edit product'), findsOneWidget);
      expect(tester.widget<TextField>(_nameField).controller!.text, 'Oat milk');
      expect(result.returned, isFalse);

      repository.result = Right(_updated);
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(repository.updateCalls, hasLength(2));
      expect(result.product, _updated);
    });
  });

  group('leaving', () {
    for (final (label, leave) in [
      ('✕', _tapClose),
      ('system back', _systemBack),
    ]) {
      testWidgets('$label without changes leaves right away', (tester) async {
        final result = await _open(tester);

        await leave(tester);

        expect(find.text('Discard changes?'), findsNothing);
        expect(result.returned, isTrue);
        expect(result.product, isNull);
      });

      testWidgets('$label with changes asks first: Keep editing stays, '
          'Discard leaves', (tester) async {
        final repository = _RecordingProductRepository(result: Right(_updated));
        final result = await _open(tester, repository: repository);
        await _enter(tester, _nameField, 'Oat milk');

        await leave(tester);
        expect(find.text('Discard changes?'), findsOneWidget);

        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsNothing);
        expect(find.text('Edit product'), findsOneWidget);
        expect(
          tester.widget<TextField>(_nameField).controller!.text,
          'Oat milk',
        );
        expect(result.returned, isFalse);

        await leave(tester);
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();

        expect(find.text('Edit product'), findsNothing);
        expect(result.returned, isTrue);
        expect(result.product, isNull);
        expect(repository.updateCalls, isEmpty);
      });
    }
  });
}
