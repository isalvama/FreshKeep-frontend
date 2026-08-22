import 'storage_spot_request_model.dart';

class CreateSpaceRequestModel {
  final String spaceName;
  final String emoji;
  final List<StorageSpotRequestModel> storageSpots;

  const CreateSpaceRequestModel({
    required this.spaceName,
    required this.emoji,
    required this.storageSpots,
  });

  Map<String, dynamic> toJson() => {
    'spaceName': spaceName,
    'emoji': emoji,
    'storageSpots': storageSpots.map((spot) => spot.toJson()).toList(),
  };
}
