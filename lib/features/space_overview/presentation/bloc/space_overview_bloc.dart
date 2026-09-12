import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/space_overview.dart';
import '../../domain/usecases/get_space_overview_usecase.dart';

part 'space_overview_event.dart';
part 'space_overview_state.dart';

class SpaceOverviewBloc extends Bloc<SpaceOverviewEvent, SpaceOverviewState> {
  final GetSpaceOverviewUseCase getSpaceOverviewUseCase;

  SpaceOverviewBloc({required this.getSpaceOverviewUseCase})
    : super(SpaceOverviewState.initial()) {
    on<SpaceOverviewRequested>(_onRequested);
  }

  Future<void> _onRequested(
    SpaceOverviewRequested event,
    Emitter<SpaceOverviewState> emit,
  ) async {
    emit(state.copyWith(status: const SpaceOverviewLoading()));

    final result = await getSpaceOverviewUseCase(spaceId: event.spaceId);

    result.match(
      (failure) => emit(
        state.copyWith(status: SpaceOverviewLoadFailure(failure.message)),
      ),
      (overview) =>
          emit(state.copyWith(status: SpaceOverviewLoadSuccess(overview))),
    );
  }
}
