part of 'create_space_bloc.dart';

sealed class CreateSpaceStatus {
  const CreateSpaceStatus();
}

final class CreateSpaceInitial extends CreateSpaceStatus {
  const CreateSpaceInitial();
}

final class CreateSpaceSubmitting extends CreateSpaceStatus {
  const CreateSpaceSubmitting();
}

final class CreateSpaceSuccess extends CreateSpaceStatus {
  final Space space;

  const CreateSpaceSuccess(this.space);
}

final class CreateSpaceError extends CreateSpaceStatus {
  final String message;

  const CreateSpaceError(this.message);
}

class StorageSpotRow extends Equatable {
  final String key; // local id for list/widget identity — NOT a backend id
  final String name;
  final StorageSpotType type;

  const StorageSpotRow({
    required this.key,
    required this.name,
    required this.type,
  });

  StorageSpotRow copyWith({String? name, StorageSpotType? type}) {
    return StorageSpotRow(
      key: key,
      name: name ?? this.name,
      type: type ?? this.type,
    );
  }

  @override
  List<Object?> get props => [key, name, type];
}

class CreateSpaceState extends Equatable {
  static const String defaultEmoji = '🏠';
  static const String defaultSpotKey = 'default-fridge';

  final String spaceName;
  final String emoji;
  final List<StorageSpotRow> spots;
  final CreateSpaceStatus status;
  final bool isDirty;

  const CreateSpaceState({
    required this.spaceName,
    required this.emoji,
    required this.spots,
    required this.status,
    required this.isDirty,
  });

  factory CreateSpaceState.initial() {
    return const CreateSpaceState(
      spaceName: '',
      emoji: defaultEmoji,
      spots: [
        StorageSpotRow(
          key: defaultSpotKey,
          name: 'Fridge',
          type: StorageSpotType.fridge,
        ),
      ],
      status: CreateSpaceInitial(),
      isDirty: false,
    );
  }

  bool get isSpaceNameValid => isValidSpaceOrSpotName(spaceName);

  /// Keys of rows that share the same trimmed/case-insensitive name and type
  /// as another row. Rows with an invalid name are ignored here — an empty
  /// or too-short name is already flagged by [spotErrors].
  Set<String> get duplicateSpotKeys {
    final firstKeyBySignature = <String, String>{};
    final duplicates = <String>{};
    for (final row in spots) {
      if (!isValidSpaceOrSpotName(row.name)) continue;
      final signature = '${row.name.trim().toLowerCase()}|${row.type.name}';
      final firstKey = firstKeyBySignature[signature];
      if (firstKey != null) {
        duplicates.add(firstKey);
        duplicates.add(row.key);
      } else {
        firstKeyBySignature[signature] = row.key;
      }
    }
    return duplicates;
  }

  /// Per-row validation message, or null when the row has no error.
  Map<String, String?> get spotErrors {
    final duplicates = duplicateSpotKeys;
    return {
      for (final row in spots)
        row.key: !isValidSpaceOrSpotName(row.name)
            ? 'Enter 1-30 characters, with at least one letter.'
            : duplicates.contains(row.key)
            ? 'Another spot already has this name and type.'
            : null,
    };
  }

  bool get canSubmit {
    if (status is CreateSpaceSubmitting) return false;
    if (!isSpaceNameValid) return false;
    if (spots.isEmpty) return false;
    if (spots.any((row) => !isValidSpaceOrSpotName(row.name))) return false;
    if (duplicateSpotKeys.isNotEmpty) return false;
    return true;
  }

  CreateSpaceState copyWith({
    String? spaceName,
    String? emoji,
    List<StorageSpotRow>? spots,
    CreateSpaceStatus? status,
    bool? isDirty,
  }) {
    return CreateSpaceState(
      spaceName: spaceName ?? this.spaceName,
      emoji: emoji ?? this.emoji,
      spots: spots ?? this.spots,
      status: status ?? this.status,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  List<Object?> get props => [spaceName, emoji, spots, status, isDirty];
}
