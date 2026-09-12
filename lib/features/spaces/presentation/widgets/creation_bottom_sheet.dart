import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../shopping_receipt/presentation/bloc/shopping_receipt_bloc.dart';
import '../bloc/spaces_bloc.dart';

Future<void> showCreationBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kCornerRadius)),
    ),
    builder: (context) => const _CreationBottomSheet(),
  );
}

class _CreationBottomSheet extends StatelessWidget {
  const _CreationBottomSheet();

  @override
  Widget build(BuildContext context) {
    final hasSpaces = context.watch<SpacesBloc>().state.spaces.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: kCornerBorderRadius),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/create-space');
                },
                child: const Text('Create a New Space'),
              ),
            ),
            if (hasSpaces) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: kCornerBorderRadius),
                  ),
                  onPressed: () {
                    context.read<ShoppingReceiptBloc>().add(
                      const ShoppingReceiptFlowReset(),
                    );
                    Navigator.of(context).pop();
                    context.push('/process-receipt/space');
                  },
                  child: const Text('Process a New Receipt'),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
