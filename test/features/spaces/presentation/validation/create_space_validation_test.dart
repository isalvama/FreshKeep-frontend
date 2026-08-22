import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_type.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/create_space_bloc.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/validation/space_form_validators.dart';

void main() {
  group('isValidSpaceOrSpotName', () {
    test('rejects an empty name', () {
      expect(isValidSpaceOrSpotName(''), isFalse);
      expect(isValidSpaceOrSpotName('   '), isFalse);
    });

    test('rejects a name longer than 30 characters', () {
      expect(isValidSpaceOrSpotName('a' * 31), isFalse);
    });

    test('accepts a name up to 30 characters', () {
      expect(isValidSpaceOrSpotName('a' * 30), isTrue);
    });

    test('rejects a numeric-only or symbol-only name', () {
      expect(isValidSpaceOrSpotName('123'), isFalse);
      expect(isValidSpaceOrSpotName('!!!'), isFalse);
    });

    test('accepts a name containing at least one letter', () {
      expect(isValidSpaceOrSpotName('Kitchen'), isTrue);
      expect(isValidSpaceOrSpotName('Room 2'), isTrue);
    });
  });

  group('CreateSpaceState.duplicateSpotKeys', () {
    test('flags two spots sharing the same name and type', () {
      final state = CreateSpaceState.initial().copyWith(
        spaceName: 'Kitchen',
        spots: const [
          StorageSpotRow(key: 'a', name: 'Fridge', type: StorageSpotType.fridge),
          StorageSpotRow(key: 'b', name: 'fridge', type: StorageSpotType.fridge),
        ],
      );

      expect(state.duplicateSpotKeys, {'a', 'b'});
    });

    test('does not flag the same name with a different type', () {
      final state = CreateSpaceState.initial().copyWith(
        spots: const [
          StorageSpotRow(key: 'a', name: 'Shelf', type: StorageSpotType.pantry),
          StorageSpotRow(key: 'b', name: 'Shelf', type: StorageSpotType.shelf),
        ],
      );

      expect(state.duplicateSpotKeys, isEmpty);
    });
  });

  group('CreateSpaceState.canSubmit', () {
    test('is false for the untouched default state (blank space name)', () {
      expect(CreateSpaceState.initial().canSubmit, isFalse);
    });

    test('is true once spaceName and the default spot are valid', () {
      final state = CreateSpaceState.initial().copyWith(spaceName: 'Kitchen');
      expect(state.canSubmit, isTrue);
    });

    test('is false when there are no storage spots', () {
      final state = CreateSpaceState.initial().copyWith(
        spaceName: 'Kitchen',
        spots: const [],
      );
      expect(state.canSubmit, isFalse);
    });

    test('is false when a duplicate spot exists', () {
      final state = CreateSpaceState.initial().copyWith(
        spaceName: 'Kitchen',
        spots: const [
          StorageSpotRow(key: 'a', name: 'Fridge', type: StorageSpotType.fridge),
          StorageSpotRow(key: 'b', name: 'Fridge', type: StorageSpotType.fridge),
        ],
      );
      expect(state.canSubmit, isFalse);
    });

    test('is false when any spot has an invalid name', () {
      final state = CreateSpaceState.initial().copyWith(
        spaceName: 'Kitchen',
        spots: const [
          StorageSpotRow(key: 'a', name: 'Fridge', type: StorageSpotType.fridge),
          StorageSpotRow(key: 'b', name: '', type: StorageSpotType.shelf),
        ],
      );
      expect(state.canSubmit, isFalse);
    });
  });
}
