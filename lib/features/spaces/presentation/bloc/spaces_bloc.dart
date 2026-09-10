import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/space.dart';
import '../../domain/usecases/get_user_spaces_usecase.dart';

part 'spaces_event.dart';
part 'spaces_state.dart';

class SpacesBloc extends Bloc<SpacesEvent, SpacesState> {
  final GetUserSpacesUseCase getUserSpacesUseCase;

  SpacesBloc({required this.getUserSpacesUseCase})
    : super(SpacesState.initial()) {
    on<SpaceCreated>(_onSpaceCreated);
    on<SpacesRequested>(_onSpacesRequested);
  }

  void _onSpaceCreated(SpaceCreated event, Emitter<SpacesState> emit) {
    emit(
      state.copyWith(
        spaces: [...state.spaces, event.space],
        errorMessage: state.errorMessage,
      ),
    );
  }

  Future<void> _onSpacesRequested(
    SpacesRequested event,
    Emitter<SpacesState> emit,
  ) async {
    emit(state.copyWith(status: SpacesStatus.loading, errorMessage: null));

    final result = await getUserSpacesUseCase();

    result.match(
      (failure) => emit(
        state.copyWith(
          status: SpacesStatus.loadFailure,
          errorMessage: failure.message,
        ),
      ),
      (spaces) => emit(
        state.copyWith(
          spaces: spaces,
          status: SpacesStatus.loaded,
          errorMessage: null,
        ),
      ),
    );
  }
}
