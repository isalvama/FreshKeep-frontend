import '../../domain/entities/space.dart';
import 'storage_spot_response_model.dart';

class SpaceResponseModel {
  final String id;
  final String spaceName;
  final String emoji;
  final List<StorageSpotResponseModel> storageSpots;
  final String creatorId;
  final List<String> participantIds;

  const SpaceResponseModel({
    required this.id,
    required this.spaceName,
    required this.emoji,
    required this.storageSpots,
    required this.creatorId,
    required this.participantIds,
  });

  factory SpaceResponseModel.fromJson(Map<String, dynamic> json) {
    return SpaceResponseModel(
      id: json['id'] as String,
      spaceName: json['spaceName'] as String,
      emoji: json['emoji'] as String,
      storageSpots: (json['storageSpots'] as List<dynamic>)
          .map(
            (spot) =>
                StorageSpotResponseModel.fromJson(spot as Map<String, dynamic>),
          )
          .toList(),
      creatorId: json['creatorId'] as String,
      participantIds: (json['participantIds'] as List<dynamic>)
          .map((id) => id as String)
          .toList(),
    );
  }

  Space toEntity() {
    return Space(
      id: id,
      spaceName: spaceName,
      emoji: emoji,
      storageSpots: storageSpots.map((spot) => spot.toEntity()).toList(),
      creatorId: creatorId,
      participantIds: participantIds,
    );
  }
}
