import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../shared/widgets/storage_spot_type_icon.dart';
import '../../../spaces/domain/entities/space.dart';
import '../../../spaces/presentation/bloc/spaces_bloc.dart';
import '../../../spaces/presentation/widgets/storage_spot_type_sheet.dart';
import '../../domain/entities/move_destination.dart';

/// Lets the user pick a storage spot from any of their spaces: first the
/// space, then one of its spots. Returns `null` when dismissed.
Future<MoveDestination?> showMoveDestinationSheet(
  BuildContext context, {
  required String currentSpaceId,
  required String currentStorageSpotId,
}) {
  return showModalBottomSheet<MoveDestination>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kCornerRadius)),
    ),
    builder: (context) => _MoveDestinationSheet(
      currentSpaceId: currentSpaceId,
      currentStorageSpotId: currentStorageSpotId,
    ),
  );
}

class _MoveDestinationSheet extends StatefulWidget {
  const _MoveDestinationSheet({
    required this.currentSpaceId,
    required this.currentStorageSpotId,
  });

  final String currentSpaceId;
  final String currentStorageSpotId;

  @override
  State<_MoveDestinationSheet> createState() => _MoveDestinationSheetState();
}

class _MoveDestinationSheetState extends State<_MoveDestinationSheet> {
  /// `null` while the space list (level 1) is shown.
  Space? _openedSpace;

  @override
  void initState() {
    super.initState();
    final spacesBloc = context.read<SpacesBloc>();
    final status = spacesBloc.state.status;
    if (status == SpacesStatus.initial || status == SpacesStatus.loadFailure) {
      spacesBloc.add(const SpacesRequested());
    }
  }

  /// Spaces with at least one spot, the current space first.
  List<Space> _destinationSpaces(List<Space> spaces) {
    final withSpots = spaces.where((s) => s.storageSpots.isNotEmpty);
    return [
      ...withSpots.where((s) => s.id == widget.currentSpaceId),
      ...withSpots.where((s) => s.id != widget.currentSpaceId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: BlocBuilder<SpacesBloc, SpacesState>(
          builder: (context, state) {
            return switch (state.status) {
              SpacesStatus.initial ||
              SpacesStatus.loading => const _SheetMessage.loading(),
              SpacesStatus.loadFailure => _SheetMessage.failure(
                message: state.errorMessage ?? "Couldn't load your spaces.",
                onRetry: () =>
                    context.read<SpacesBloc>().add(const SpacesRequested()),
              ),
              SpacesStatus.loaded =>
                _openedSpace == null
                    ? _buildSpaceList(_destinationSpaces(state.spaces))
                    : _buildSpotList(_openedSpace!),
            };
          },
        ),
      ),
    );
  }

  Widget _buildSpaceList(List<Space> spaces) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetHeader(title: 'Move to'),
        if (spaces.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No storage spots available.'),
          )
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final space in spaces)
                  ListTile(
                    leading: space.emoji.isEmpty
                        ? null
                        : Text(
                            space.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                    title: Text(
                      space.id == widget.currentSpaceId
                          ? '${space.spaceName} (current)'
                          : space.spaceName,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _openedSpace = space),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSpotList(Space space) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(
          title: space.spaceName,
          onBack: () => setState(() => _openedSpace = null),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final spot in space.storageSpots)
                if (spot.id == widget.currentStorageSpotId)
                  ListTile(
                    enabled: false,
                    // A disabled ListTile greys its text but not images.
                    leading: Opacity(
                      opacity: 0.38,
                      child: StorageSpotTypeIcon(type: spot.type),
                    ),
                    title: Text(spot.name),
                    subtitle: Text(storageSpotTypeLabel(spot.type)),
                    trailing: const Text('Current'),
                  )
                else
                  ListTile(
                    leading: StorageSpotTypeIcon(type: spot.type),
                    title: Text(spot.name),
                    subtitle: Text(storageSpotTypeLabel(spot.type)),
                    onTap: () => Navigator.of(context).pop(
                      MoveDestination(
                        spaceId: space.id,
                        spaceName: space.spaceName,
                        storageSpotId: spot.id,
                        storageSpotName: spot.name,
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: onBack,
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage.loading() : message = null, onRetry = null;

  const _SheetMessage.failure({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: message == null
          ? const Center(heightFactor: 1, child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
    );
  }
}
