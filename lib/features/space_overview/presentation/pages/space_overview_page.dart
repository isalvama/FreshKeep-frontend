import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/product_type_icon.dart';
import '../../../../shared/widgets/storage_spot_type_icon.dart';
import '../../../products/domain/entities/updated_product.dart';
import '../../../shopping_receipt/domain/entities/persisted_product.dart';
import '../../../spaces/domain/entities/space.dart';
import '../../../spaces/domain/entities/storage_spot.dart';
import '../../../spaces/presentation/bloc/space_invitation_bloc.dart';
import '../../../spaces/presentation/widgets/space_invitation_dialog.dart';
import '../../domain/entities/move_destination.dart';
import '../bloc/space_overview_bloc.dart';
import '../widgets/move_destination_sheet.dart';

class SpaceOverviewPage extends StatelessWidget {
  const SpaceOverviewPage({super.key, required this.spaceId, this.space});

  final String spaceId;

  /// Passed as GoRouter `extra` when opened from Home; only used for the
  /// AppBar title until the overview loads.
  final Space? space;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SpaceInvitationBloc>(
      create: (_) => getIt<SpaceInvitationBloc>(),
      child: MultiBlocListener(
        listeners: [
          BlocListener<SpaceOverviewBloc, SpaceOverviewState>(
            listenWhen: (previous, current) =>
                previous.deletionStatus != current.deletionStatus,
            listener: _showDeletionFeedback,
          ),
          BlocListener<SpaceOverviewBloc, SpaceOverviewState>(
            listenWhen: (previous, current) =>
                previous.moveStatus != current.moveStatus,
            listener: _showMoveFeedback,
          ),
          BlocListener<SpaceInvitationBloc, SpaceInvitationState>(
            listener: _showInvitationFeedback,
          ),
        ],
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return BlocBuilder<SpaceOverviewBloc, SpaceOverviewState>(
      builder: (context, state) {
        final status = state.status;

        if (status is SpaceOverviewLoadFailure) {
          return Scaffold(
            appBar: _buildAppBar(context, _fallbackTitle),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(status.message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.read<SpaceOverviewBloc>().add(
                        SpaceOverviewRequested(spaceId),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (status is SpaceOverviewLoadSuccess) {
          final overview = status.overview;
          final storageSpotsById = {
            for (final spot in overview.storageSpots) spot.id: spot,
          };

          // While selecting, back clears the selection instead of leaving.
          return PopScope(
            canPop: !state.isSelecting,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              context.read<SpaceOverviewBloc>().add(
                const ProductSelectionCleared(),
              );
            },
            child: Scaffold(
              appBar: state.isSelecting
                  ? _buildSelectionAppBar(context, state)
                  : _buildAppBar(
                      context,
                      '${overview.emoji} ${overview.name}',
                      actions: [_buildInviteAction()],
                    ),
              body: overview.productResults.isEmpty
                  ? const Center(child: Text('No products yet.'))
                  : ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        for (final product in overview.productResults)
                          _OverviewProductTile(
                            product: product,
                            storageSpot:
                                storageSpotsById[product.storageSpotId],
                            isSelecting: state.isSelecting,
                            isSelected: state.selectedProductIds.contains(
                              product.id,
                            ),
                            onOpen: () => _openEditor(context, product),
                          ),
                      ],
                    ),
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(context, _fallbackTitle),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  String get _fallbackTitle {
    final space = this.space;
    return space != null ? '${space.emoji} ${space.spaceName}' : 'Space';
  }

  /// Opened from Home (pushed), the default back arrow pops. Reached from the
  /// receipt flow (`go`), there is nothing to pop, so the leading button
  /// goes to Home instead.
  AppBar _buildAppBar(
    BuildContext context,
    String title, {
    List<Widget>? actions,
  }) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: Navigator.of(context).canPop()
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Home',
              onPressed: () => context.go('/home'),
            ),
    );
  }

  /// Each tap creates a new invitation; the result is shown by
  /// [_showInvitationFeedback].
  Widget _buildInviteAction() {
    return BlocBuilder<SpaceInvitationBloc, SpaceInvitationState>(
      builder: (context, state) {
        if (state.status == SpaceInvitationStatus.inProgress) {
          return _actionSpinner;
        }
        return IconButton(
          icon: const Icon(Icons.person_add_alt_1),
          tooltip: 'Invite',
          onPressed: () => context.read<SpaceInvitationBloc>().add(
            SpaceInvitationRequested(spaceId),
          ),
        );
      },
    );
  }

  AppBar _buildSelectionAppBar(BuildContext context, SpaceOverviewState state) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel selection',
        onPressed: state.isBusy
            ? null
            : () => context.read<SpaceOverviewBloc>().add(
                const ProductSelectionCleared(),
              ),
      ),
      title: Text('${state.selectedProductIds.length} selected'),
      actions: [
        if (state.moveStatus is ProductMoveInProgress)
          _actionSpinner
        else
          _buildMoveAction(context, state),
        if (state.deletionStatus is ProductDeletionInProgress)
          _actionSpinner
        else
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete selected',
            onPressed: state.isBusy
                ? null
                : () =>
                      _confirmDelete(context, state.selectedProductIds.length),
          ),
      ],
    );
  }

  /// Enabled only for exactly one selected product that has a storage spot:
  /// the endpoint moves one product and needs its current spot.
  Widget _buildMoveAction(BuildContext context, SpaceOverviewState state) {
    final status = state.status;
    final selected =
        state.selectedProductIds.length == 1 &&
            status is SpaceOverviewLoadSuccess
        ? status.overview.productResults
              .where((p) => p.id == state.selectedProductIds.single)
              .firstOrNull
        : null;
    final hasNoSpot = selected != null && selected.storageSpotId == null;
    final canMove = selected != null && !hasNoSpot && !state.isBusy;

    return IconButton(
      icon: const Icon(Icons.drive_file_move_outline),
      tooltip: hasNoSpot ? 'This product has no storage spot' : 'Move',
      onPressed: canMove
          ? () => _startMove(
              context,
              selected,
              (status as SpaceOverviewLoadSuccess).overview.id,
            )
          : null,
    );
  }

  /// Destination sheet, then confirmation, then the move request.
  Future<void> _startMove(
    BuildContext context,
    PersistedProduct product,
    String currentSpaceId,
  ) async {
    final destination = await showMoveDestinationSheet(
      context,
      currentSpaceId: currentSpaceId,
      currentStorageSpotId: product.storageSpotId!,
    );
    if (destination == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Move '),
              TextSpan(
                text: product.productName,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const TextSpan(text: ' to '),
              TextSpan(
                text: _destinationLabel(destination),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const TextSpan(
                text: '? Its expiration date will be recalculated.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<SpaceOverviewBloc>().add(
      SelectedProductMoveSubmitted(destination),
    );
  }

  Future<void> _confirmDelete(BuildContext context, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${_productCount(count)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<SpaceOverviewBloc>().add(
      const SelectedProductsDeleteSubmitted(),
    );
  }

  /// The editor pops with the saved product, or with nothing when the user
  /// leaves without saving.
  Future<void> _openEditor(
    BuildContext context,
    PersistedProduct product,
  ) async {
    final updated = await context.push<UpdatedProduct>(
      '/space-overview/$spaceId/products/${product.id}/edit',
      extra: product,
    );
    if (updated == null || !context.mounted) return;
    context.read<SpaceOverviewBloc>().add(ProductUpdated(updated));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Product updated')));
  }

  void _showInvitationFeedback(
    BuildContext context,
    SpaceInvitationState state,
  ) {
    switch (state.status) {
      case SpaceInvitationStatus.success:
        final overviewStatus = context.read<SpaceOverviewBloc>().state.status;
        showSpaceInvitationDialog(
          context,
          spaceName: overviewStatus is SpaceOverviewLoadSuccess
              ? overviewStatus.overview.name
              : space?.spaceName ?? 'this space',
          invitation: state.invitation!,
        );
      case SpaceInvitationStatus.failure:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage ?? '')));
      case SpaceInvitationStatus.initial || SpaceInvitationStatus.inProgress:
        break;
    }
  }

  void _showMoveFeedback(BuildContext context, SpaceOverviewState state) {
    final message = switch (state.moveStatus) {
      ProductMoveSuccess(:final destination, :final newExpirationDate) =>
        'Moved to ${_destinationLabel(destination)}. '
            'New expiration date: ${_formatDate(newExpirationDate)}',
      ProductMoveFailure(:final message) => message,
      _ => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showDeletionFeedback(BuildContext context, SpaceOverviewState state) {
    final message = switch (state.deletionStatus) {
      ProductDeletionSuccess(:final deletedCount) =>
        '${_productCount(deletedCount)} deleted',
      ProductDeletionFailure(:final message) => message,
      _ => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Replaces an AppBar action while its request runs.
const _actionSpinner = Padding(
  padding: EdgeInsets.all(16),
  child: SizedBox.square(
    dimension: 24,
    child: CircularProgressIndicator(strokeWidth: 2),
  ),
);

String _destinationLabel(MoveDestination destination) =>
    '${destination.spaceName} · ${destination.storageSpotName}';

String _productCount(int count) => count == 1 ? '1 product' : '$count products';

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Outside selection mode a tap opens the editor ([onOpen]) and a long press
/// starts selection mode with this product selected; inside it, tapping the
/// row (or its checkbox) toggles the product.
class _OverviewProductTile extends StatelessWidget {
  const _OverviewProductTile({
    required this.product,
    required this.storageSpot,
    required this.isSelecting,
    required this.isSelected,
    required this.onOpen,
  });

  final PersistedProduct product;
  final StorageSpot? storageSpot;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final spotLabel = storageSpot?.name ?? 'No suggested spot';
    void toggle() => context.read<SpaceOverviewBloc>().add(
      ProductSelectionToggled(product.id),
    );

    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelecting)
            Checkbox(value: isSelected, onChanged: (_) => toggle()),
          ProductTypeIcon.fromName(product.productType),
        ],
      ),
      title: Text(product.productName),
      titleTextStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontSize: 18),
      subtitle: Text(
        '$spotLabel · '
        'exp. date: ${_formatDate(product.expirationDate)}',
      ),
      trailing: storageSpot == null
          ? null
          : StorageSpotTypeIcon(type: storageSpot!.type),
      selected: isSelected,
      onTap: isSelecting ? toggle : onOpen,
      onLongPress: isSelecting ? null : toggle,
    );
  }
}
