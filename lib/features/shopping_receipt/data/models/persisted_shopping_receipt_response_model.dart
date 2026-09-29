import '../../../spaces/data/models/storage_spot_response_model.dart';
import '../../domain/entities/persisted_shopping_receipt.dart';
import 'persisted_product_response_model.dart';

class PersistedShoppingReceiptResponseModel {
  final String id;
  final DateTime shoppingDate;
  final String storeName;
  final List<PersistedProductResponseModel> products;
  final List<StorageSpotResponseModel> storageSpots;

  const PersistedShoppingReceiptResponseModel({
    required this.id,
    required this.shoppingDate,
    required this.storeName,
    required this.products,
    required this.storageSpots,
  });

  factory PersistedShoppingReceiptResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PersistedShoppingReceiptResponseModel(
      id: json['id'] as String,
      shoppingDate: DateTime.parse(json['shoppingDate'] as String),
      storeName: json['storeName'] as String,
      products: (json['products'] as List<dynamic>)
          .map(
            (product) => PersistedProductResponseModel.fromJson(
              product as Map<String, dynamic>,
            ),
          )
          .toList(),
      storageSpots: (json['storageSpots'] as List<dynamic>)
          .map(
            (spot) =>
                StorageSpotResponseModel.fromJson(spot as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  PersistedShoppingReceipt toEntity() {
    return PersistedShoppingReceipt(
      id: id,
      shoppingDate: shoppingDate,
      storeName: storeName,
      products: products.map((product) => product.toEntity()).toList(),
      storageSpots: storageSpots.map((spot) => spot.toEntity()).toList(),
    );
  }
}
