import 'package:equatable/equatable.dart';

import 'storage_spot_type.dart';

class StorageSpot extends Equatable {
  final String id;
  final String name;
  final StorageSpotType type;

  const StorageSpot({required this.id, required this.name, required this.type});

  @override
  List<Object?> get props => [id, name, type];
}
