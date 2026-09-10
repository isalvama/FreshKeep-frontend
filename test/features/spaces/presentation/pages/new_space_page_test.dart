import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_input.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/repositories/space_repository.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/create_space_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/create_space_bloc.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/pages/new_space_page.dart';

class _NeverCalledSpaceRepository implements SpaceRepository {
  @override
  Future<Either<SpaceFailure, Space>> createSpace({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  }) {
    throw StateError('createSpace should not be called in this test');
  }

  @override
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces() {
    throw StateError('getUserSpaces should not be called in this test');
  }
}

Future<void> _pumpNewSpacePage(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<CreateSpaceBloc>(
        create: (_) => CreateSpaceBloc(
          createSpaceUseCase: CreateSpaceUseCase(_NeverCalledSpaceRepository()),
        ),
        child: const NewSpacePage(),
      ),
    ),
  );
}

ElevatedButton _createButton(WidgetTester tester) {
  return tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Create'),
  );
}

void main() {
  testWidgets('starts with a default Fridge row and a disabled Create button', (
    tester,
  ) async {
    await _pumpNewSpacePage(tester);

    expect(find.text('New Space'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Fridge'), findsOneWidget);
    expect(_createButton(tester).onPressed, isNull);
  });

  testWidgets('Create becomes enabled once a valid space name is entered', (
    tester,
  ) async {
    await _pumpNewSpacePage(tester);

    await tester.enterText(find.byType(TextField).first, 'Kitchen');
    await tester.pump();

    expect(_createButton(tester).onPressed, isNotNull);
  });

  testWidgets('"Add Another Storage Spot" appends a row; trash removes it', (
    tester,
  ) async {
    await _pumpNewSpacePage(tester);

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Another Storage Spot'));
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('duplicate name+type rows are flagged and block Create', (
    tester,
  ) async {
    await _pumpNewSpacePage(tester);

    await tester.enterText(find.byType(TextField).first, 'Kitchen');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Another Storage Spot'));
    await tester.pump();

    // Second spot row's name field: TextField index 2 (0 = space name, 1 = first spot).
    await tester.enterText(find.byType(TextField).at(2), 'Fridge');
    await tester.pump();

    expect(find.text('Another spot already has this name and type.'), findsWidgets);
    expect(_createButton(tester).onPressed, isNull);
  });

  testWidgets('navigating back while dirty shows the discard-changes dialog', (
    tester,
  ) async {
    await _pumpNewSpacePage(tester);

    await tester.enterText(find.byType(TextField).first, 'Kitchen');
    await tester.pump();

    // Simulates the OS back gesture/button, routed through PopScope.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
  });
}
