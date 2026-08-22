part of 'spaces_bloc.dart';

class SpacesState extends Equatable {
  final List<Space> spaces;

  const SpacesState({required this.spaces});

  @override
  List<Object?> get props => [spaces];
}
