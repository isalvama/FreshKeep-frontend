import '../../domain/entities/storage_spot_type.dart';

class StorageSpotRequestModel {
  final String name;
  final StorageSpotType type;

  const StorageSpotRequestModel({required this.name, required this.type});

  Map<String, dynamic> toJson() => {'name': name, 'type': type.wireValue};
}
