import 'package:flutter/material.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../shared/widgets/storage_spot_type_icon.dart';
import '../../domain/entities/storage_spot_type.dart';
import 'storage_spot_type_sheet.dart';

class StorageSpotRowWidget extends StatefulWidget {
  final String name;
  final StorageSpotType type;
  final String? errorText;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<StorageSpotType> onTypeChanged;
  final VoidCallback onRemove;

  const StorageSpotRowWidget({
    super.key,
    required this.name,
    required this.type,
    required this.errorText,
    required this.onNameChanged,
    required this.onTypeChanged,
    required this.onRemove,
  });

  @override
  State<StorageSpotRowWidget> createState() => _StorageSpotRowWidgetState();
}

class _StorageSpotRowWidgetState extends State<StorageSpotRowWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
  }

  @override
  void didUpdateWidget(covariant StorageSpotRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync when the value changed from outside this field (e.g. a form
    // reset) — not on every rebuild, which would otherwise fight the user's
    // cursor position while typing.
    if (widget.name != _controller.text) {
      _controller.text = widget.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickType() async {
    final selected = await showStorageSpotTypeSheet(
      context,
      selected: widget.type,
    );
    if (selected != null) widget.onTypeChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: widget.onNameChanged,
                  decoration: InputDecoration(
                    hintText: 'Spot name',
                    border: OutlineInputBorder(
                      borderRadius: kCornerBorderRadius,
                    ),
                    errorText: widget.errorText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _pickType,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: kCornerBorderRadius,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StorageSpotTypeIcon(type: widget.type, size: 24),
                    const SizedBox(width: 8),
                    Text(storageSpotTypeLabel(widget.type)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove storage spot',
                onPressed: widget.onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
