import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/create_space_bloc.dart';
import '../bloc/spaces_bloc.dart';
import '../widgets/emoji_picker_button.dart';
import '../widgets/storage_spot_row.dart';
import 'create_space_result.dart';

class NewSpacePage extends StatefulWidget {
  const NewSpacePage({super.key});

  @override
  State<NewSpacePage> createState() => _NewSpacePageState();
}

class _NewSpacePageState extends State<NewSpacePage> {
  late final TextEditingController _spaceNameController;

  @override
  void initState() {
    super.initState();
    _spaceNameController = TextEditingController(
      text: context.read<CreateSpaceBloc>().state.spaceName,
    );
  }

  @override
  void dispose() {
    _spaceNameController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handlePop() async {
    final bloc = context.read<CreateSpaceBloc>();
    if (!bloc.state.isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final discard = await _confirmDiscard();
    if (!mounted) return;
    if (discard) {
      bloc.add(const CreateSpaceReset());
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('New Space'), centerTitle: true),
        body: BlocConsumer<CreateSpaceBloc, CreateSpaceState>(
          listener: (context, state) {
            final status = state.status;
            if (status is CreateSpaceSuccess) {
              context.read<SpacesBloc>().add(SpaceCreated(status.space));
              context.read<CreateSpaceBloc>().add(const CreateSpaceReset());
              context.push(
                '/create-space/status',
                extra: CreateSpaceResultSuccess(status.space),
              );
            } else if (status is CreateSpaceError) {
              context.push(
                '/create-space/status',
                extra: CreateSpaceResultError(status.message),
              );
            }
          },
          builder: (context, state) {
            if (_spaceNameController.text != state.spaceName) {
              _spaceNameController.text = state.spaceName;
            }
            final bloc = context.read<CreateSpaceBloc>();
            final isSubmitting = state.status is CreateSpaceSubmitting;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Space Name', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EmojiPickerButton(
                        emoji: state.emoji,
                        onChanged: (value) =>
                            bloc.add(EmojiChanged(value)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _spaceNameController,
                          onChanged: (value) =>
                              bloc.add(SpaceNameChanged(value)),
                          decoration: InputDecoration(
                            hintText: 'e.g. Kitchen',
                            errorText:
                                state.spaceName.isNotEmpty &&
                                    !state.isSpaceNameValid
                                ? 'Enter 1-30 characters, with at least one letter.'
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Storage Spots',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final row in state.spots)
                    StorageSpotRowWidget(
                      key: ValueKey(row.key),
                      name: row.name,
                      type: row.type,
                      errorText: state.spotErrors[row.key],
                      onNameChanged: (value) =>
                          bloc.add(StorageSpotNameChanged(row.key, value)),
                      onTypeChanged: (value) =>
                          bloc.add(StorageSpotTypeChanged(row.key, value)),
                      onRemove: () =>
                          bloc.add(StorageSpotRemoved(row.key)),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => bloc.add(const StorageSpotAdded()),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Another Storage Spot'),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: state.canSubmit
                          ? () => bloc.add(const CreateSpaceSubmitted())
                          : null,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
