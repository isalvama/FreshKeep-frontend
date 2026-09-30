import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/core/di/service_locator.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/create_space_invitation_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/join_space_invitation_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/join_space_bloc.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/space_invitation_bloc.dart';

void main() {
  setUp(() => setupServiceLocator(dio: Dio()));
  tearDown(() => getIt.reset());

  test('resolves CreateSpaceInvitationUseCase', () {
    expect(getIt<CreateSpaceInvitationUseCase>(), isNotNull);
  });

  test('resolves JoinSpaceInvitationUseCase', () {
    expect(getIt<JoinSpaceInvitationUseCase>(), isNotNull);
  });

  test('resolves a new SpaceInvitationBloc each time', () async {
    final first = getIt<SpaceInvitationBloc>();
    final second = getIt<SpaceInvitationBloc>();

    expect(first.state.status, SpaceInvitationStatus.initial);
    expect(identical(first, second), isFalse);

    await first.close();
    await second.close();
  });

  test('resolves a new JoinSpaceBloc each time', () async {
    final first = getIt<JoinSpaceBloc>();
    final second = getIt<JoinSpaceBloc>();

    expect(first.state.status, JoinSpaceStatus.initial);
    expect(identical(first, second), isFalse);

    await first.close();
    await second.close();
  });
}
