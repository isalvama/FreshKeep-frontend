import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/check_auth_status_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/current_user_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/pages/home_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/spaces_bloc.dart';

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _pumpHomePage(WidgetTester tester, {List<Space> spaces = const []}) async {
  final repository = _UnusedAuthRepository();
  final authBloc = AuthBloc(
    checkAuthStatusUseCase: CheckAuthStatusUseCase(repository),
    currentUserUseCase: CurrentUserUseCase(repository),
    logoutUseCase: LogoutUseCase(repository),
  );
  final spacesBloc = SpacesBloc();
  for (final space in spaces) {
    spacesBloc.add(SpaceCreated(space));
  }
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<SpacesBloc>.value(value: spacesBloc),
        ],
        child: const HomePage(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows an empty state and a FAB when there are no spaces', (
    tester,
  ) async {
    await _pumpHomePage(tester);

    expect(find.text('No spaces yet.'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('tapping the FAB opens the creation bottom sheet', (
    tester,
  ) async {
    await _pumpHomePage(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Create a New Space'), findsOneWidget);
    final receiptButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Add a New Receipt'),
    );
    expect(receiptButton.onPressed, isNull);
  });
}
