import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/expiration_date_badge.dart';
import '../../../../shared/widgets/product_type_icon.dart';
import '../../../../shared/widgets/storage_spot_type_icon.dart';
import '../../../spaces/domain/entities/storage_spot.dart';
import '../../domain/entities/persisted_product.dart';
import '../bloc/shopping_receipt_bloc.dart';

class ReceiptReprocessedPage extends StatelessWidget {
  const ReceiptReprocessedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShoppingReceiptBloc, ShoppingReceiptState>(
      builder: (context, state) {
        final receipt = state.reprocessedReceipt;
        if (receipt == null) {
          return const Scaffold(body: SizedBox.shrink());
        }

        final storageSpotsById = {
          for (final spot in receipt.storageSpots) spot.id: spot,
        };

        return Scaffold(
          appBar: AppBar(title: const Text('Receipt Details')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                receipt.storeName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(receipt.shoppingDate),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (final product in receipt.products)
                _ReprocessedProductTile(
                  product: product,
                  storageSpot: storageSpotsById[product.storageSpotId],
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      context.go('/space-overview/${state.spaceId}'),
                  child: const Text('OK'),
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

class _ReprocessedProductTile extends StatelessWidget {
  const _ReprocessedProductTile({
    required this.product,
    required this.storageSpot,
  });

  final PersistedProduct product;
  final StorageSpot? storageSpot;

  @override
  Widget build(BuildContext context) {
    final spotLabel = storageSpot?.name ?? 'No suggested spot';
    return ListTile(
      leading: ProductTypeIcon.fromName(product.productType),
      title: Text(product.productName),
      titleTextStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontSize: 18),
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${product.productType} · $spotLabel'),
          ExpirationDateBadge(date: product.expirationDate),
        ],
      ),
      trailing: storageSpot == null
          ? null
          : StorageSpotTypeIcon(type: storageSpot!.type),
    );
  }
}
