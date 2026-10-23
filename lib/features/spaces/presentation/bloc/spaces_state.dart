part of 'spaces_bloc.dart';

enum SpacesStatus { initial, loading, loaded, loadFailure }

class SpacesState extends Equatable {
  final List<Space> spaces;
  final SpacesStatus status;
  final String? errorMessage;

  const SpacesState({
    required this.spaces,
    required this.status,
    this.errorMessage,
  });

  factory SpacesState.initial() {
    return const SpacesState(spaces: [], status: SpacesStatus.initial);
  }

  SpacesState copyWith({
    List<Space>? spaces,
    SpacesStatus? status,
    String? errorMessage,
  }) {
    return SpacesState(
      spaces: spaces ?? this.spaces,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [spaces, status, errorMessage];
}
