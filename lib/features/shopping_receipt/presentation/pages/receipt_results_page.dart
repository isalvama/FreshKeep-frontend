import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../spaces/domain/entities/storage_spot.dart';
import '../../domain/entities/product_extraction.dart';
import '../bloc/shopping_receipt_bloc.dart';

class ReceiptResultsPage extends StatelessWidget {
  const ReceiptResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShoppingReceiptBloc, ShoppingReceiptState>(
      builder: (context, state) {
        final status = state.status;
        if (status is! ShoppingReceiptProcessSuccess) {
          return const Scaffold(body: SizedBox.shrink());
        }

        final result = status.result;
        final storageSpotsById = {
          for (final spot in result.suggestedStorageSpots) spot.id: spot,
        };
        final flagged = result.flaggedProducts.toSet();
        final flaggedIndices = <int>[];
        final restIndices = <int>[];
        for (var i = 0; i < result.productExtractions.length; i++) {
          if (flagged.contains(result.productExtractions[i])) {
            flaggedIndices.add(i);
          } else {
            restIndices.add(i);
          }
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Receipt Details')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                result.storeName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(result.purchaseShoppingDate),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (flaggedIndices.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: kCornerBorderRadius,
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        for (final index in flaggedIndices)
                          _ProductTile(
                            product: result.productExtractions[index],
                            storageSpot: storageSpotsById[result
                                .productExtractions[index]
                                .suggestedStorageSpotId],
                            selected: state.selectedForReprocess.contains(
                              index,
                            ),
                            onChanged: (_) => context
                                .read<ShoppingReceiptBloc>()
                                .add(ReprocessSelectionToggled(index)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              for (final index in restIndices)
                _ProductTile(
                  product: result.productExtractions[index],
                  storageSpot:
                      storageSpotsById[result
                          .productExtractions[index]
                          .suggestedStorageSpotId],
                  selected: state.selectedForReprocess.contains(index),
                  onChanged: (_) => context
                      .read<ShoppingReceiptBloc>()
                      .add(ReprocessSelectionToggled(index)),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: kCornerBorderRadius,
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: kCornerBorderRadius,
                    ),
                  ),
                  child: const Text('Reprocess selected products'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.storageSpot,
    required this.selected,
    required this.onChanged,
  });

  final ProductExtraction product;
  final StorageSpot? storageSpot;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final spotLabel = storageSpot?.name ?? 'No suggested spot';
    return CheckboxListTile(
      value: selected,
      onChanged: onChanged,
      title: Text(product.productName),
      subtitle: Text(
        '${product.productType} · $spotLabel · '
        'exp. ${_formatDate(product.expirationDate)}',
      ),
    );
  }
}
