import '../../domain/entities/storage_spot.dart';
import '../../domain/entities/storage_spot_type.dart';

class StorageSpotResponseModel {
  final String storageSpotId;
  final String storageSpotName;
  final StorageSpotType storageSpotType;

  const StorageSpotResponseModel({
    required this.storageSpotId,
    required this.storageSpotName,
    required this.storageSpotType,
  });

  factory StorageSpotResponseModel.fromJson(Map<String, dynamic> json) {
    return StorageSpotResponseModel(
      storageSpotId: json['storageSpotId'] as String,
      storageSpotName: json['storageSpotName'] as String,
      storageSpotType: StorageSpotType.fromWireValue(
        json['storageSpotType'] as String,
      ),
    );
  }

  StorageSpot toEntity() {
    return StorageSpot(
      id: storageSpotId,
      name: storageSpotName,
      type: storageSpotType,
    );
  }
}
