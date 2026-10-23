import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/product_type_icon.dart';
import '../../domain/entities/currency.dart';
import '../../domain/entities/product_type.dart';
import '../bloc/edit_product_bloc.dart';

/// Edits one product. Pops with the `UpdatedProduct` on a successful save,
/// and with no result when the user leaves without saving.
class EditProductPage extends StatefulWidget {
  const EditProductPage({super.key});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    final state = context.read<EditProductBloc>().state;
    _nameController = TextEditingController(text: state.name);
    _amountController = TextEditingController(text: state.amountText);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditProductBloc, EditProductState>(
      listenWhen: (previous, current) =>
          previous.saveStatus != current.saveStatus,
      listener: _onSaveStatusChanged,
      builder: (context, state) {
        final bloc = context.read<EditProductBloc>();
        final enabled = !state.isSaving;

        // Back and ✕ both go through here: blocked while saving, and a
        // confirmation first when there are unsaved changes.
        return PopScope(
          canPop: !state.isSaving && !state.hasChanges,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || state.isSaving) return;
            _confirmDiscard(context);
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: enabled
                    ? () => Navigator.of(context).maybePop()
                    : null,
              ),
              title: const Text('Edit product'),
              actions: [
                if (state.isSaving)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton(
                    onPressed: state.canSave
                        ? () => bloc.add(const EditProductSaveSubmitted())
                        : null,
                    child: const Text('Save'),
                  ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  key: const Key('edit_product_name'),
                  controller: _nameController,
                  enabled: enabled,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: state.nameError,
                  ),
                  onChanged: (value) => bloc.add(EditProductNameChanged(value)),
                ),
                const SizedBox(height: 16),
                InkWell(
                  key: const Key('edit_product_expiration_date'),
                  onTap: enabled ? () => _pickDate(context, state) : null,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Expiration date',
                      enabled: enabled,
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(_formatDate(state.expirationDate)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ProductType>(
                  key: const Key('edit_product_type'),
                  initialValue: state.productType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  hint: _unknownHint(state.original.productType),
                  disabledHint: state.productType != null
                      ? _ProductTypeOption(state.productType!)
                      : _unknownHint(state.original.productType),
                  items: [
                    for (final type in ProductType.values)
                      DropdownMenuItem(
                        value: type,
                        child: _ProductTypeOption(type),
                      ),
                  ],
                  onChanged: enabled
                      ? (type) => bloc.add(EditProductTypeChanged(type!))
                      : null,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('edit_product_amount'),
                  controller: _amountController,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    errorText: state.amountError,
                  ),
                  onChanged: (value) =>
                      bloc.add(EditProductAmountChanged(value)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Currency>(
                  key: const Key('edit_product_currency'),
                  initialValue: state.currency,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Currency',
                    errorText: state.currencyError,
                  ),
                  hint: _unknownHint(state.original.currency),
                  disabledHint: state.currency != null
                      ? Text(state.currency!.label)
                      : _unknownHint(state.original.currency),
                  items: [
                    for (final currency in Currency.values)
                      DropdownMenuItem(
                        value: currency,
                        child: Text(currency.label),
                      ),
                  ],
                  onChanged: enabled
                      ? (currency) =>
                            bloc.add(EditProductCurrencyChanged(currency!))
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onSaveStatusChanged(BuildContext context, EditProductState state) {
    switch (state.saveStatus) {
      case ProductSaveSuccess(:final product):
        context.pop(product);
      case ProductSaveFailure(:final message):
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      case ProductSaveIdle() || ProductSaveInProgress():
        break;
    }
  }

  Future<void> _pickDate(BuildContext context, EditProductState state) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDate(state.expirationDate),
      firstDate: _firstPickableDate,
      lastDate: _lastPickableDate,
    );
    if (picked == null || !context.mounted) return;
    context.read<EditProductBloc>().add(
      EditProductExpirationDateChanged(picked),
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard != true || !context.mounted) return;
    context.pop();
  }
}

/// Hint for a dropdown whose original value isn't a known constant; nothing
/// when the product had no value at all.
Widget? _unknownHint(String? originalValue) =>
    originalValue != null ? Text('Unknown ($originalValue)') : null;

// Past dates are allowed so a wrong expiration date can be corrected.
final _firstPickableDate = DateTime(2000);
final _lastPickableDate = DateTime(2100, 12, 31);

/// `showDatePicker` asserts when `initialDate` is outside its range.
DateTime _clampDate(DateTime date) {
  if (date.isBefore(_firstPickableDate)) return _firstPickableDate;
  if (date.isAfter(_lastPickableDate)) return _lastPickableDate;
  return date;
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// A product type's icon and label, for the Type dropdown.
class _ProductTypeOption extends StatelessWidget {
  const _ProductTypeOption(this.type);

  final ProductType type;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProductTypeIcon(type: type, size: 24),
        const SizedBox(width: 12),
        Flexible(child: Text(type.label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
