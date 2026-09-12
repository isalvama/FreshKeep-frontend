import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../spaces/presentation/bloc/spaces_bloc.dart';
import '../bloc/shopping_receipt_bloc.dart';

class SpacePickerPage extends StatelessWidget {
  const SpacePickerPage({super.key});

  Future<void> _onSpaceSelected(BuildContext context, String spaceId) async {
    context.read<ShoppingReceiptBloc>().add(SpaceForReceiptSelected(spaceId));

    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null || !context.mounted) return;

    context.read<ShoppingReceiptBloc>().add(
      ReceiptImagePicked(pickedFile.path),
    );
    context.push('/process-receipt/confirm-image');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Space'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: BlocBuilder<SpacesBloc, SpacesState>(
        builder: (context, state) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.spaces.length,
            itemBuilder: (context, index) {
              final space = state.spaces[index];
              return ListTile(
                leading: Text(
                  space.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(space.spaceName),
                onTap: () => _onSpaceSelected(context, space.id),
              );
            },
          );
        },
      ),
    );
  }
}
