import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../shared/widgets/product_type_icon.dart';
import '../../../spaces/domain/entities/storage_spot.dart';
import '../../domain/entities/product_extraction.dart';
import '../bloc/shopping_receipt_bloc.dart';

class ReceiptResultsPage extends StatelessWidget {
  const ReceiptResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShoppingReceiptBloc, ShoppingReceiptState>(
      listenWhen: (previous, current) {
        final confirmedJustNow =
            previous.status is! ShoppingReceiptConfirmSuccess &&
            current.status is ShoppingReceiptConfirmSuccess;
        final reprocessedJustNow =
            previous.status is! ShoppingReceiptReprocessSuccess &&
            current.status is ShoppingReceiptReprocessSuccess;
        final failureCountChanged =
            previous.consecutiveFailureCount != current.consecutiveFailureCount;
        return confirmedJustNow || reprocessedJustNow || failureCountChanged;
      },
      listener: (context, state) {
        final status = state.status;
        if (status is ShoppingReceiptConfirmSuccess) {
          context.go('/space-overview/${state.spaceId}');
          return;
        }
        if (status is ShoppingReceiptReprocessSuccess) {
          context.push('/process-receipt/reprocessed-results');
          return;
        }
        if (state.consecutiveFailureCount >= 2) {
          context.push('/process-receipt/error');
        } else if (state.consecutiveFailureCount == 1) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_failureMessage(status))));
        }
      },
      builder: (context, state) {
        final result = state.extraction;
        if (result == null) {
          return const Scaffold(body: SizedBox.shrink());
        }

        final status = state.status;
        final isSubmitting =
            status is ShoppingReceiptConfirming ||
            status is ShoppingReceiptReprocessing;
        final storageSpotsById = {
          for (final spot in result.suggestedStorageSpots) spot.id: spot,
        };
        final flaggedIndices = <int>[];
        final restIndices = <int>[];
        for (var i = 0; i < result.productExtractions.length; i++) {
          if (state.flaggedIndices.contains(i)) {
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      state.storeName ?? result.storeName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit store name',
                    onPressed: isSubmitting
                        ? null
                        : () => _editStoreName(
                            context,
                            state.storeName ?? result.storeName,
                          ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    _formatDate(
                      state.shoppingDate ?? result.purchaseShoppingDate,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    tooltip: 'Edit shopping date',
                    onPressed: isSubmitting
                        ? null
                        : () => _editShoppingDate(
                            context,
                            state.shoppingDate ?? result.purchaseShoppingDate,
                          ),
                  ),
                ],
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
                            expirationDate: state.displayedExpirationDate(
                              index,
                            ),
                            storageSpot:
                                storageSpotsById[result
                                    .productExtractions[index]
                                    .suggestedStorageSpotId],
                            selected: state.selectedForReprocess.contains(
                              index,
                            ),
                            onChanged: (_) => context
                                .read<ShoppingReceiptBloc>()
                                .add(ReprocessSelectionToggled(index)),
                            edited: state.editedExpirationDates.containsKey(
                              index,
                            ),
                            onEditExpirationDate: isSubmitting
                                ? null
                                : () => _editExpirationDate(
                                    context,
                                    index,
                                    state,
                                  ),
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
                  expirationDate: state.displayedExpirationDate(index),
                  storageSpot:
                      storageSpotsById[result
                          .productExtractions[index]
                          .suggestedStorageSpotId],
                  selected: state.selectedForReprocess.contains(index),
                  onChanged: (_) => context.read<ShoppingReceiptBloc>().add(
                    ReprocessSelectionToggled(index),
                  ),
                  edited: state.editedExpirationDates.containsKey(index),
                  onEditExpirationDate: isSubmitting
                      ? null
                      : () => _editExpirationDate(context, index, state),
                ),
              const SizedBox(height: 32),
              if (isSubmitting) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () => context.read<ShoppingReceiptBloc>().add(
                          const ReceiptConfirmSubmitted(),
                        ),
                  child: const Text('OK'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting || state.selectedForReprocess.isEmpty
                      ? null
                      : () => _submitReprocess(context, state.hasPendingEdits),
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

Future<void> _editStoreName(BuildContext context, String current) async {
  final edited = await showDialog<String>(
    context: context,
    builder: (_) => _StoreNameDialog(initialValue: current),
  );
  if (edited == null || !context.mounted) return;
  context.read<ShoppingReceiptBloc>().add(ReceiptStoreNameEdited(edited));
}

Future<void> _editShoppingDate(BuildContext context, DateTime current) async {
  final today = DateUtils.dateOnly(DateTime.now());
  final firstDate = DateTime(today.year - 1, today.month, today.day);
  final picked = await showDatePicker(
    context: context,
    initialDate: _clampDate(current, firstDate, today),
    firstDate: firstDate,
    lastDate: today,
  );
  if (picked == null || !context.mounted) return;
  context.read<ShoppingReceiptBloc>().add(ReceiptShoppingDateEdited(picked));
}

Future<void> _editExpirationDate(
  BuildContext context,
  int index,
  ShoppingReceiptState state,
) async {
  final today = DateUtils.dateOnly(DateTime.now());
  final firstDate = DateUtils.dateOnly(
    state.shoppingDate ?? state.extraction!.purchaseShoppingDate,
  );
  final lastDate = DateTime(today.year + 10, today.month, today.day);
  final picked = await showDatePicker(
    context: context,
    initialDate: _clampDate(
      state.displayedExpirationDate(index),
      firstDate,
      lastDate,
    ),
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (picked == null || !context.mounted) return;
  context.read<ShoppingReceiptBloc>().add(
    ProductExpirationDateEdited(index, picked),
  );
}

/// Reprocess never carries edits, so with pending edits the user must confirm
/// discarding them first.
Future<void> _submitReprocess(
  BuildContext context,
  bool hasPendingEdits,
) async {
  if (hasPendingEdits) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard your edits?'),
        content: const Text(
          'Reprocessing re-extracts the receipt with AI and discards your '
          'edits (shopping date, store name, expiration dates). Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;
  }
  context.read<ShoppingReceiptBloc>().add(const ReceiptReprocessSubmitted());
}

/// `showDatePicker` asserts when `initialDate` is outside its range, e.g. for
/// a receipt older than a year or an AI-extracted expiration date earlier than
/// the shopping date.
DateTime _clampDate(DateTime date, DateTime min, DateTime max) {
  if (date.isBefore(min)) return min;
  if (date.isAfter(max)) return max;
  return date;
}

String _failureMessage(ShoppingReceiptStatus status) {
  if (status is ShoppingReceiptConfirmFailure) return status.message;
  if (status is ShoppingReceiptReprocessFailure) return status.message;
  return 'Something went wrong.';
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.expirationDate,
    required this.storageSpot,
    required this.selected,
    required this.onChanged,
    required this.edited,
    required this.onEditExpirationDate,
  });

  final ProductExtraction product;
  final DateTime expirationDate;
  final StorageSpot? storageSpot;
  final bool selected;
  final ValueChanged<bool?> onChanged;
  final bool edited;
  final VoidCallback? onEditExpirationDate;

  @override
  Widget build(BuildContext context) {
    final spotLabel = storageSpot?.name ?? 'No suggested spot';
    // A ListTile rather than a CheckboxListTile, which has no room for the
    // type icon next to the checkbox. Tapping the row still toggles it.
    return ListTile(
      onTap: () => onChanged(!selected),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: selected, onChanged: onChanged),
          ProductTypeIcon.fromName(product.productType),
        ],
      ),
      title: Text(product.productName),
      subtitle: Text.rich(
        TextSpan(
          text:
              '${product.productType} · $spotLabel · '
              'exp. ${_formatDate(expirationDate)}',
          children: [
            if (edited)
              TextSpan(
                text: ' · edited',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today),
        tooltip: 'Edit expiration date',
        onPressed: onEditExpirationDate,
      ),
    );
  }
}

class _StoreNameDialog extends StatefulWidget {
  const _StoreNameDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_StoreNameDialog> createState() => _StoreNameDialogState();
}

class _StoreNameDialogState extends State<_StoreNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Store name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Store name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            return TextButton(
              // Read the controller at tap time, not the value captured at
              // the last build, so a tap right after typing saves the new text.
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_controller.text.trim()),
              child: const Text('Save'),
            );
          },
        ),
      ],
    );
  }
}
