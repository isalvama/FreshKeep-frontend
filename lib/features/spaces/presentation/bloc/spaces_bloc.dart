import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/space.dart';

part 'spaces_event.dart';
part 'spaces_state.dart';

class SpacesBloc extends Bloc<SpacesEvent, SpacesState> {
  SpacesBloc() : super(const SpacesState(spaces: [])) {
    on<SpaceCreated>(_onSpaceCreated);
  }

  void _onSpaceCreated(SpaceCreated event, Emitter<SpacesState> emit) {
    emit(SpacesState(spaces: [...state.spaces, event.space]));
  }
}
