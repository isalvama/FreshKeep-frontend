import 'package:equatable/equatable.dart';

import 'storage_spot.dart';

class Space extends Equatable {
  final String id;
  final String spaceName;
  final String emoji; // held client-side; the backend response never echoes it back
  final List<StorageSpot> storageSpots;
  final String creatorId;
  final List<String> participantIds;

  const Space({
    required this.id,
    required this.spaceName,
    required this.emoji,
    required this.storageSpots,
    required this.creatorId,
    required this.participantIds,
  });

  @override
  List<Object?> get props => [
    id,
    spaceName,
    emoji,
    storageSpots,
    creatorId,
    participantIds,
  ];
}
