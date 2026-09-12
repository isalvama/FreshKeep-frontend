import '../../../shopping_receipt/data/models/persisted_product_response_model.dart';
import '../../../spaces/data/models/storage_spot_response_model.dart';
import '../../domain/entities/space_overview.dart';

class SpaceOverviewResponseModel {
  final String id;
  final String name;
  final String emoji;
  final List<StorageSpotResponseModel> storageSpots;
  final List<PersistedProductResponseModel> productResults;

  const SpaceOverviewResponseModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.storageSpots,
    required this.productResults,
  });

  factory SpaceOverviewResponseModel.fromJson(Map<String, dynamic> json) {
    return SpaceOverviewResponseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      storageSpots: (json['storageSpots'] as List<dynamic>)
          .map(
            (spot) => StorageSpotResponseModel.fromJson(
              spot as Map<String, dynamic>,
            ),
          )
          .toList(),
      productResults: (json['productResults'] as List<dynamic>)
          .map(
            (product) => PersistedProductResponseModel.fromJson(
              product as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  SpaceOverview toEntity() {
    return SpaceOverview(
      id: id,
      name: name,
      emoji: emoji,
      storageSpots: storageSpots.map((spot) => spot.toEntity()).toList(),
      productResults: productResults
          .map((product) => product.toEntity())
          .toList(),
    );
  }
}
