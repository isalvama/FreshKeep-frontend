import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/space.dart';
import '../../domain/entities/storage_spot_input.dart';
import '../../domain/entities/storage_spot_type.dart';
import '../../domain/usecases/create_space_usecase.dart';
import '../validation/space_form_validators.dart';

part 'create_space_event.dart';
part 'create_space_state.dart';

class CreateSpaceBloc extends Bloc<CreateSpaceEvent, CreateSpaceState> {
  final CreateSpaceUseCase createSpaceUseCase;

  int _nextSpotKey = 1;

  CreateSpaceBloc({required this.createSpaceUseCase})
    : super(CreateSpaceState.initial()) {
    on<SpaceNameChanged>(_onSpaceNameChanged);
    on<EmojiChanged>(_onEmojiChanged);
    on<StorageSpotAdded>(_onStorageSpotAdded);
    on<StorageSpotRemoved>(_onStorageSpotRemoved);
    on<StorageSpotNameChanged>(_onStorageSpotNameChanged);
    on<StorageSpotTypeChanged>(_onStorageSpotTypeChanged);
    on<CreateSpaceSubmitted>(_onSubmitted);
    on<CreateSpaceReset>(_onReset);
  }

  void _onSpaceNameChanged(
    SpaceNameChanged event,
    Emitter<CreateSpaceState> emit,
  ) {
    emit(
      state.copyWith(
        spaceName: event.value,
        isDirty: _computeIsDirty(
          spaceName: event.value,
          emoji: state.emoji,
          spots: state.spots,
        ),
      ),
    );
  }

  void _onEmojiChanged(EmojiChanged event, Emitter<CreateSpaceState> emit) {
    emit(
      state.copyWith(
        emoji: event.value,
        isDirty: _computeIsDirty(
          spaceName: state.spaceName,
          emoji: event.value,
          spots: state.spots,
        ),
      ),
    );
  }

  void _onStorageSpotAdded(
    StorageSpotAdded event,
    Emitter<CreateSpaceState> emit,
  ) {
    final newRow = StorageSpotRow(
      key: 'spot-${_nextSpotKey++}',
      name: '',
      type: StorageSpotType.fridge,
    );
    final spots = [...state.spots, newRow];
    emit(
      state.copyWith(
        spots: spots,
        isDirty: _computeIsDirty(
          spaceName: state.spaceName,
          emoji: state.emoji,
          spots: spots,
        ),
      ),
    );
  }

  void _onStorageSpotRemoved(
    StorageSpotRemoved event,
    Emitter<CreateSpaceState> emit,
  ) {
    final spots = state.spots.where((row) => row.key != event.key).toList();
    emit(
      state.copyWith(
        spots: spots,
        isDirty: _computeIsDirty(
          spaceName: state.spaceName,
          emoji: state.emoji,
          spots: spots,
        ),
      ),
    );
  }

  void _onStorageSpotNameChanged(
    StorageSpotNameChanged event,
    Emitter<CreateSpaceState> emit,
  ) {
    final spots = state.spots
        .map(
          (row) =>
              row.key == event.key ? row.copyWith(name: event.value) : row,
        )
        .toList();
    emit(
      state.copyWith(
        spots: spots,
        isDirty: _computeIsDirty(
          spaceName: state.spaceName,
          emoji: state.emoji,
          spots: spots,
        ),
      ),
    );
  }

  void _onStorageSpotTypeChanged(
    StorageSpotTypeChanged event,
    Emitter<CreateSpaceState> emit,
  ) {
    final spots = state.spots
        .map(
          (row) =>
              row.key == event.key ? row.copyWith(type: event.value) : row,
        )
        .toList();
    emit(
      state.copyWith(
        spots: spots,
        isDirty: _computeIsDirty(
          spaceName: state.spaceName,
          emoji: state.emoji,
          spots: spots,
        ),
      ),
    );
  }

  Future<void> _onSubmitted(
    CreateSpaceSubmitted event,
    Emitter<CreateSpaceState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(state.copyWith(status: const CreateSpaceSubmitting()));

    final result = await createSpaceUseCase(
      spaceName: state.spaceName,
      emoji: state.emoji,
      storageSpots: state.spots
          .map((row) => StorageSpotInput(name: row.name, type: row.type))
          .toList(),
    );

    result.match(
      (failure) =>
          emit(state.copyWith(status: CreateSpaceError(failure.message))),
      (space) => emit(state.copyWith(status: CreateSpaceSuccess(space))),
    );
  }

  void _onReset(CreateSpaceReset event, Emitter<CreateSpaceState> emit) {
    emit(CreateSpaceState.initial());
  }

  bool _computeIsDirty({
    required String spaceName,
    required String emoji,
    required List<StorageSpotRow> spots,
  }) {
    if (spaceName.isNotEmpty) return true;
    if (emoji != CreateSpaceState.defaultEmoji) return true;
    final defaults = CreateSpaceState.initial().spots;
    if (spots.length != defaults.length) return true;
    for (var i = 0; i < spots.length; i++) {
      if (spots[i] != defaults[i]) return true;
    }
    return false;
  }
}
