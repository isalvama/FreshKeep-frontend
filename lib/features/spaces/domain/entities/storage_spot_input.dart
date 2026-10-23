import 'package:equatable/equatable.dart';

import 'storage_spot_type.dart';

class StorageSpotInput extends Equatable {
  final String name;
  final StorageSpotType type;

  const StorageSpotInput({required this.name, required this.type});

  @override
  List<Object?> get props => [name, type];
}
