import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/persisted_shopping_receipt.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/product_extraction.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/receipt_extraction_result.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/repositories/shopping_receipt_repository.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/confirm_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/process_new_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/reprocess_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/bloc/shopping_receipt_bloc.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/pages/confirm_image_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../test_helpers/fake_image_picker_platform.dart';

class _NeverCalledShoppingReceiptRepository
    implements ShoppingReceiptRepository {
  @override
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>>
  processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  }) => throw UnimplementedError();

  @override
  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  confirmReceipt({
    required String spaceId,
    required String shoppingReceiptId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) => throw UnimplementedError();

  @override
  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  reprocessReceipt({
    required String spaceId,
    required String shoppingReceiptId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required String language,
    required List<ProductExtraction> flaggedProducts,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) => throw UnimplementedError();
}

class _PendingShoppingReceiptRepository implements ShoppingReceiptRepository {
  final Completer<Either<ShoppingReceiptFailure, ReceiptExtractionResult>>
  completer = Completer();

  @override
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>>
  processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  }) => completer.future;

  @override
  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  confirmReceipt({
    required String spaceId,
    required String shoppingReceiptId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) => throw UnimplementedError();

  @override
  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  reprocessReceipt({
    required String spaceId,
    required String shoppingReceiptId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required String language,
    required List<ProductExtraction> flaggedProducts,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) => throw UnimplementedError();
}

ShoppingReceiptBloc _buildBlocWithImage(
  String imagePath, {
  ShoppingReceiptRepository? repository,
}) {
  final resolvedRepository =
      repository ?? _NeverCalledShoppingReceiptRepository();
  final bloc = ShoppingReceiptBloc(
    processNewShoppingReceiptUseCase: ProcessNewShoppingReceiptUseCase(
      resolvedRepository,
    ),
    confirmShoppingReceiptUseCase: ConfirmShoppingReceiptUseCase(
      resolvedRepository,
    ),
    reprocessShoppingReceiptUseCase: ReprocessShoppingReceiptUseCase(
      resolvedRepository,
    ),
  );
  bloc.add(const SpaceForReceiptSelected('space-1'));
  bloc.add(ReceiptImagePicked(imagePath));
  return bloc;
}

Future<GoRouter> _pumpFromSpacePicker(
  WidgetTester tester,
  ShoppingReceiptBloc bloc,
) async {
  final router = GoRouter(
    initialLocation: '/process-receipt/space',
    routes: [
      GoRoute(
        path: '/process-receipt/space',
        builder: (context, state) => const Text('SPACE_MARKER'),
      ),
      GoRoute(
        path: '/process-receipt/confirm-image',
        builder: (context, state) => const ConfirmImagePage(),
      ),
      GoRoute(
        path: '/process-receipt/processing',
        builder: (context, state) => const Text('PROCESSING_MARKER'),
      ),
    ],
  );

  await tester.pumpWidget(
    BlocProvider<ShoppingReceiptBloc>.value(
      value: bloc,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  router.push('/process-receipt/confirm-image');
  await tester.pumpAndSettle();

  return router;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File tempImageFile;
  late File secondTempImageFile;

  setUpAll(() async {
    tempImageFile = File(
      '${Directory.systemTemp.path}/confirm_image_page_test_1.jpg',
    );
    await tempImageFile.writeAsBytes([0xFF, 0xD8, 0xFF]);
    secondTempImageFile = File(
      '${Directory.systemTemp.path}/confirm_image_page_test_2.jpg',
    );
    await secondTempImageFile.writeAsBytes([0xFF, 0xD8, 0xFF]);
  });

  tearDownAll(() async {
    if (await tempImageFile.exists()) await tempImageFile.delete();
    if (await secondTempImageFile.exists()) {
      await secondTempImageFile.delete();
    }
  });

  testWidgets('displays the picked image at full size', (tester) async {
    final bloc = _buildBlocWithImage(tempImageFile.path);

    await _pumpFromSpacePicker(tester, bloc);

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as FileImage).file.path, tempImageFile.path);
  });

  testWidgets(
    'OK dispatches ReceiptProcessingSubmitted and pushes the processing screen',
    (tester) async {
      final bloc = _buildBlocWithImage(
        tempImageFile.path,
        repository: _PendingShoppingReceiptRepository(),
      );

      await _pumpFromSpacePicker(tester, bloc);

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(bloc.state.status, isA<ShoppingReceiptProcessing>());
      expect(find.text('PROCESSING_MARKER'), findsOneWidget);
    },
  );

  testWidgets(
    'back pops and, on a new pick, replaces the image and re-shows this screen',
    (tester) async {
      ImagePickerPlatform.instance = FakeImagePickerPlatform([
        XFile(secondTempImageFile.path),
      ]);
      final bloc = _buildBlocWithImage(tempImageFile.path);

      await _pumpFromSpacePicker(tester, bloc);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(bloc.state.imagePath, secondTempImageFile.path);
      expect(find.text('SPACE_MARKER'), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as FileImage).file.path, secondTempImageFile.path);
    },
  );

  testWidgets(
    'back with a cancelled repick leaves the user on the space picker',
    (tester) async {
      ImagePickerPlatform.instance = FakeImagePickerPlatform([null]);
      final bloc = _buildBlocWithImage(tempImageFile.path);

      await _pumpFromSpacePicker(tester, bloc);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('SPACE_MARKER'), findsOneWidget);
    },
  );
}
