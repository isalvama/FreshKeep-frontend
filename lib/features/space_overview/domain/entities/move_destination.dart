import 'package:equatable/equatable.dart';

/// What the destination sheet returns. The names are only there for the
/// confirmation dialog and the SnackBar.
class MoveDestination extends Equatable {
  final String spaceId;
  final String spaceName;
  final String storageSpotId;
  final String storageSpotName;

  const MoveDestination({
    required this.spaceId,
    required this.spaceName,
    required this.storageSpotId,
    required this.storageSpotName,
  });

  @override
  List<Object?> get props => [
    spaceId,
    spaceName,
    storageSpotId,
    storageSpotName,
  ];
}
