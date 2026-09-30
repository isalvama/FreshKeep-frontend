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
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/join_space_invitation_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/join_space_bloc.dart';

/// Answers each `joinInvitation` call with the next entry of [results]; a
/// `null` entry waits on [pending].
class _JoinRepository implements SpaceRepository {
  _JoinRepository(this.results);

  final List<Either<SpaceFailure, String>?> results;
  final Completer<Either<SpaceFailure, String>> pending = Completer();
  final List<String> calls = [];

  @override
  Future<Either<SpaceFailure, String>> joinInvitation({
    required String token,
  }) async {
    final result = results[calls.length];
    calls.add(token);
    return result ?? pending.future;
  }

  @override
  Future<Either<SpaceFailure, SpaceInvitation>> createInvitation({
    required String spaceId,
  }) => throw UnimplementedError();

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

const _expired = Left<SpaceFailure, String>(
  SpaceValidationFailure('This invitation is invalid or has expired.'),
);

JoinSpaceBloc _buildBloc(_JoinRepository repository) => JoinSpaceBloc(
  joinSpaceInvitationUseCase: JoinSpaceInvitationUseCase(repository),
);

/// Lets the stubbed use case resolve and the handler emit.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Submits [token] to a fresh bloc over [repository] and returns what it
/// emitted.
Future<List<JoinSpaceState>> _emittedFor(_JoinRepository repository) async {
  final bloc = _buildBloc(repository);
  final emitted = <JoinSpaceState>[];
  final subscription = bloc.stream.listen(emitted.add);

  bloc.add(const JoinSpaceSubmitted('token-1'));
  await _settle();

  await subscription.cancel();
  await bloc.close();
  return emitted;
}

void main() {
  test('starts in initial', () {
    final bloc = _buildBloc(_JoinRepository([]));

    expect(bloc.state, const JoinSpaceState.initial());
  });

  test('emits inProgress then success with the joined spaceId', () async {
    final repository = _JoinRepository([const Right('space-9')]);

    expect(await _emittedFor(repository), [
      const JoinSpaceState.inProgress(),
      const JoinSpaceState.success('space-9'),
    ]);
    expect(repository.calls, ['token-1']);
  });

  test('a SpaceConflictFailure emits alreadyParticipant', () async {
    final repository = _JoinRepository([
      const Left(SpaceConflictFailure("You're already in this space.")),
    ]);

    expect(await _emittedFor(repository), [
      const JoinSpaceState.inProgress(),
      const JoinSpaceState.alreadyParticipant("You're already in this space."),
    ]);
  });

  test('any other failure emits failure with the message', () async {
    final repository = _JoinRepository([_expired]);

    expect(await _emittedFor(repository), [
      const JoinSpaceState.inProgress(),
      const JoinSpaceState.failure(
        'This invitation is invalid or has expired.',
      ),
    ]);
  });

  test('a submit while one is in progress does not call the use case '
      'again', () async {
    final repository = _JoinRepository([null]);
    final bloc = _buildBloc(repository);
    final emitted = <JoinSpaceState>[];
    final subscription = bloc.stream.listen(emitted.add);

    bloc.add(const JoinSpaceSubmitted('token-1'));
    await _settle();
    bloc.add(const JoinSpaceSubmitted('token-1'));
    await _settle();

    expect(repository.calls, ['token-1']);

    repository.pending.complete(const Right('space-9'));
    await _settle();

    expect(emitted, [
      const JoinSpaceState.inProgress(),
      const JoinSpaceState.success('space-9'),
    ]);
    await subscription.cancel();
    await bloc.close();
  });

  test('closing while a join is pending finishes cleanly', () async {
    final repository = _JoinRepository([null]);
    final bloc = _buildBloc(repository);

    bloc.add(const JoinSpaceSubmitted('token-1'));
    await _settle();
    final closing = bloc.close();
    repository.pending.complete(const Right('space-9'));

    await expectLater(closing, completes);
    expect(bloc.isClosed, isTrue);
  });

  testWidgets('two failures in a row with the same message both reach a '
      'BlocListener', (tester) async {
    final bloc = _buildBloc(_JoinRepository([_expired, _expired]));
    final failures = <String?>[];

    await tester.pumpWidget(
      BlocListener<JoinSpaceBloc, JoinSpaceState>(
        bloc: bloc,
        listener: (_, state) {
          if (state.status == JoinSpaceStatus.failure) {
            failures.add(state.errorMessage);
          }
        },
        child: const SizedBox(),
      ),
    );

    bloc.add(const JoinSpaceSubmitted('token-1'));
    await tester.pump();
    bloc.add(const JoinSpaceSubmitted('token-1'));
    await tester.pump();

    expect(failures, [
      'This invitation is invalid or has expired.',
      'This invitation is invalid or has expired.',
    ]);
  });
}
