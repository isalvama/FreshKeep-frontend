import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space_invitation.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_input.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/repositories/space_repository.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/create_space_invitation_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/space_invitation_bloc.dart';

/// Answers each `createInvitation` call with the next entry of [results]; a
/// `null` entry waits on [pending].
class _InvitationRepository implements SpaceRepository {
  _InvitationRepository(this.results);

  final List<Either<SpaceFailure, SpaceInvitation>?> results;
  final Completer<Either<SpaceFailure, SpaceInvitation>> pending = Completer();
  final List<String> calls = [];

  @override
  Future<Either<SpaceFailure, String>> joinInvitation({
    required String token,
  }) => throw UnimplementedError();

  @override
  Future<Either<SpaceFailure, SpaceInvitation>> createInvitation({
    required String spaceId,
  }) async {
    final result = results[calls.length];
    calls.add(spaceId);
    return result ?? pending.future;
  }

  @override
  Future<Either<SpaceFailure, Space>> createSpace({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  }) => throw UnimplementedError();

  @override
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces() =>
      throw UnimplementedError();
}

final _invitation = SpaceInvitation(
  id: 'invitation-1',
  token: 'token-1',
  spaceId: 'space-1',
  expiresAt: DateTime.utc(2026, 9, 29, 21),
);

const _failure = Left<SpaceFailure, SpaceInvitation>(
  SpaceConflictFailure("You're not a participant of this space."),
);

SpaceInvitationBloc _buildBloc(_InvitationRepository repository) =>
    SpaceInvitationBloc(
      createSpaceInvitationUseCase: CreateSpaceInvitationUseCase(repository),
    );

/// Lets the stubbed use case resolve and the handler emit.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('starts in initial', () {
    final bloc = _buildBloc(_InvitationRepository([]));

    expect(bloc.state, const SpaceInvitationState.initial());
  });

  test('emits inProgress then success with the invitation', () async {
    final repository = _InvitationRepository([Right(_invitation)]);
    final bloc = _buildBloc(repository);
    final emitted = <SpaceInvitationState>[];
    final subscription = bloc.stream.listen(emitted.add);

    bloc.add(const SpaceInvitationRequested('space-1'));
    await _settle();

    expect(emitted, [
      const SpaceInvitationState.inProgress(),
      SpaceInvitationState.success(_invitation),
    ]);
    expect(repository.calls, ['space-1']);
    await subscription.cancel();
    await bloc.close();
  });

  test('emits inProgress then failure with the message', () async {
    final bloc = _buildBloc(_InvitationRepository([_failure]));
    final emitted = <SpaceInvitationState>[];
    final subscription = bloc.stream.listen(emitted.add);

    bloc.add(const SpaceInvitationRequested('space-1'));
    await _settle();

    expect(emitted, [
      const SpaceInvitationState.inProgress(),
      const SpaceInvitationState.failure(
        "You're not a participant of this space.",
      ),
    ]);
    await subscription.cancel();
    await bloc.close();
  });

  test('a request while one is in progress does not call the use case '
      'again', () async {
    final repository = _InvitationRepository([null]);
    final bloc = _buildBloc(repository);
    final emitted = <SpaceInvitationState>[];
    final subscription = bloc.stream.listen(emitted.add);

    bloc.add(const SpaceInvitationRequested('space-1'));
    await _settle();
    bloc.add(const SpaceInvitationRequested('space-1'));
    await _settle();

    expect(repository.calls, ['space-1']);

    repository.pending.complete(Right(_invitation));
    await _settle();

    expect(emitted, [
      const SpaceInvitationState.inProgress(),
      SpaceInvitationState.success(_invitation),
    ]);
    await subscription.cancel();
    await bloc.close();
  });

  test('each request after a result creates a new invitation', () async {
    final second = SpaceInvitation(
      id: 'invitation-2',
      token: 'token-2',
      spaceId: 'space-1',
      expiresAt: DateTime.utc(2026, 9, 29, 22),
    );
    final repository = _InvitationRepository([
      Right(_invitation),
      Right(second),
    ]);
    final bloc = _buildBloc(repository);

    bloc.add(const SpaceInvitationRequested('space-1'));
    await _settle();
    bloc.add(const SpaceInvitationRequested('space-1'));
    await _settle();

    expect(repository.calls, hasLength(2));
    expect(bloc.state, SpaceInvitationState.success(second));
    await bloc.close();
  });

  test('closing while a request is pending finishes cleanly', () async {
    final repository = _InvitationRepository([null]);
    final bloc = _buildBloc(repository);

    bloc.add(const SpaceInvitationRequested('space-1'));
    await _settle();
    final closing = bloc.close();
    repository.pending.complete(Right(_invitation));

    await expectLater(closing, completes);
    expect(bloc.isClosed, isTrue);
  });

  testWidgets('two failures in a row with the same message both reach a '
      'BlocListener', (tester) async {
    final bloc = _buildBloc(_InvitationRepository([_failure, _failure]));
    final failures = <String?>[];

    await tester.pumpWidget(
      BlocListener<SpaceInvitationBloc, SpaceInvitationState>(
        bloc: bloc,
        listener: (_, state) {
          if (state.status == SpaceInvitationStatus.failure) {
            failures.add(state.errorMessage);
          }
        },
        child: const SizedBox(),
      ),
    );

    bloc.add(const SpaceInvitationRequested('space-1'));
    await tester.pump();
    bloc.add(const SpaceInvitationRequested('space-1'));
    await tester.pump();

    expect(failures, [
      "You're not a participant of this space.",
      "You're not a participant of this space.",
    ]);
  });
}
