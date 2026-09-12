import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/receipt_extraction_result.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/repositories/shopping_receipt_repository.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/process_new_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/bloc/shopping_receipt_bloc.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/pages/space_picker_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/repositories/space_repository.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/get_user_spaces_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/spaces_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../test_helpers/fake_image_picker_platform.dart';

class _NeverCalledShoppingReceiptRepository implements ShoppingReceiptRepository {
  @override
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>> processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  }) => throw UnimplementedError();
}

class _StubSpaceRepository implements SpaceRepository {
  _StubSpaceRepository(this.spaces);

  final List<Space> spaces;

  @override
  Future<Either<SpaceFailure, Space>> createSpace({
    required String spaceName,
    required String emoji,
    required List storageSpots,
  }) => throw UnimplementedError();

  @override
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces() async =>
      Right(spaces);
}

const _space1 = Space(
  id: 'space-1',
  spaceName: 'Kitchen',
  emoji: '🏠',
  storageSpots: [],
  creatorId: 'user-1',
  participantIds: ['user-1'],
);

const _space2 = Space(
  id: 'space-2',
  spaceName: 'Garage',
  emoji: '🚗',
  storageSpots: [],
  creatorId: 'user-1',
  participantIds: ['user-1'],
);

Future<SpacesBloc> _seededSpacesBloc(List<Space> spaces) async {
  final bloc = SpacesBloc(
    getUserSpacesUseCase: GetUserSpacesUseCase(_StubSpaceRepository(spaces)),
  );
  bloc.add(const SpacesRequested());
  await bloc.stream.first;
  return bloc;
}

ShoppingReceiptBloc _buildShoppingReceiptBloc() {
  return ShoppingReceiptBloc(
    processNewShoppingReceiptUseCase: ProcessNewShoppingReceiptUseCase(
      _NeverCalledShoppingReceiptRepository(),
    ),
  );
}

Future<void> _pumpSpacePickerPage(
  WidgetTester tester,
  SpacesBloc spacesBloc,
  ShoppingReceiptBloc shoppingReceiptBloc,
) async {
  final router = GoRouter(
    initialLocation: '/process-receipt/space',
    routes: [
      GoRoute(
        path: '/process-receipt/space',
        builder: (context, state) => const SpacePickerPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Text('HOME_MARKER'),
      ),
      GoRoute(
        path: '/process-receipt/confirm-image',
        builder: (context, state) => const Text('CONFIRM_IMAGE_MARKER'),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<SpacesBloc>.value(value: spacesBloc),
        BlocProvider<ShoppingReceiptBloc>.value(value: shoppingReceiptBloc),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  late File tempImageFile;

  setUpAll(() async {
    tempImageFile = File(
      '${Directory.systemTemp.path}/space_picker_page_test.jpg',
    );
    await tempImageFile.writeAsBytes([0xFF, 0xD8, 0xFF]);
  });

  tearDownAll(() async {
    if (await tempImageFile.exists()) {
      await tempImageFile.delete();
    }
  });

  testWidgets('lists every space with its emoji and name', (tester) async {
    final spacesBloc = await _seededSpacesBloc([_space1, _space2]);

    await _pumpSpacePickerPage(tester, spacesBloc, _buildShoppingReceiptBloc());

    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('🏠'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
    expect(find.text('🚗'), findsOneWidget);
  });

  testWidgets('the back button navigates to /home', (tester) async {
    final spacesBloc = await _seededSpacesBloc([_space1]);

    await _pumpSpacePickerPage(tester, spacesBloc, _buildShoppingReceiptBloc());

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('HOME_MARKER'), findsOneWidget);
  });

  testWidgets(
    'selecting a space stores the spaceId and, on a successful pick, '
    'stores the image and navigates to the confirm-image screen',
    (tester) async {
      ImagePickerPlatform.instance = FakeImagePickerPlatform([
        XFile(tempImageFile.path),
      ]);
      final spacesBloc = await _seededSpacesBloc([_space1]);
      final shoppingReceiptBloc = _buildShoppingReceiptBloc();

      await _pumpSpacePickerPage(tester, spacesBloc, shoppingReceiptBloc);

      await tester.tap(find.text('Kitchen'));
      await tester.pumpAndSettle();

      expect(shoppingReceiptBloc.state.spaceId, 'space-1');
      expect(shoppingReceiptBloc.state.imagePath, tempImageFile.path);
      expect(find.text('CONFIRM_IMAGE_MARKER'), findsOneWidget);
    },
  );

  testWidgets(
    'cancelling the native picker leaves the user on this screen',
    (tester) async {
      ImagePickerPlatform.instance = FakeImagePickerPlatform([null]);
      final spacesBloc = await _seededSpacesBloc([_space1]);
      final shoppingReceiptBloc = _buildShoppingReceiptBloc();

      await _pumpSpacePickerPage(tester, spacesBloc, shoppingReceiptBloc);

      await tester.tap(find.text('Kitchen'));
      await tester.pumpAndSettle();

      expect(shoppingReceiptBloc.state.imagePath, isNull);
      expect(find.text('Kitchen'), findsOneWidget);
      expect(find.text('CONFIRM_IMAGE_MARKER'), findsNothing);
    },
  );
}
