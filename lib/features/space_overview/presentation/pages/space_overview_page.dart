import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../shopping_receipt/domain/entities/persisted_product.dart';
import '../../../spaces/domain/entities/space.dart';
import '../../../spaces/domain/entities/storage_spot.dart';
import '../bloc/space_overview_bloc.dart';

class SpaceOverviewPage extends StatelessWidget {
  const SpaceOverviewPage({super.key, required this.spaceId, this.space});

  final String spaceId;

  /// Passed as GoRouter `extra` when opened from Home; only used for the
  /// AppBar title until the overview loads.
  final Space? space;

  @override
  Widget build(BuildContext context) {
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

          return Scaffold(
            appBar: _buildAppBar(context, '${overview.emoji} ${overview.name}'),
            body: overview.productResults.isEmpty
                ? const Center(child: Text('No products yet.'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final product in overview.productResults)
                        _OverviewProductTile(
                          product: product,
                          storageSpot: storageSpotsById[product.storageSpotId],
                        ),
                    ],
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
  AppBar _buildAppBar(BuildContext context, String title) {
    return AppBar(
      title: Text(title),
      leading: Navigator.of(context).canPop()
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Home',
              onPressed: () => context.go('/home'),
            ),
    );
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _OverviewProductTile extends StatelessWidget {
  const _OverviewProductTile({
    required this.product,
    required this.storageSpot,
  });

  final PersistedProduct product;
  final StorageSpot? storageSpot;

  @override
  Widget build(BuildContext context) {
    final spotLabel = storageSpot?.name ?? 'No suggested spot';
    return ListTile(
      title: Text(product.productName),
      subtitle: Text(
        '${product.productType} · $spotLabel · '
        'exp. ${_formatDate(product.expirationDate)}',
      ),
    );
  }
}
