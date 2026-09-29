import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/shopping_receipt_bloc.dart';

class ConfirmImagePage extends StatelessWidget {
  const ConfirmImagePage({super.key});

  Future<void> _onBack(BuildContext context) async {
    Navigator.of(context).pop();

    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null || !context.mounted) return;

    context.read<ShoppingReceiptBloc>().add(
      ReceiptImagePicked(pickedFile.path),
    );
    context.push('/process-receipt/confirm-image');
  }

  void _onConfirm(BuildContext context) {
    context.read<ShoppingReceiptBloc>().add(const ReceiptProcessingSubmitted());
    context.push('/process-receipt/processing');
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = context.watch<ShoppingReceiptBloc>().state.imagePath;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => _onBack(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'OK',
            onPressed: () => _onConfirm(context),
          ),
        ],
      ),
      body: Center(
        child: imagePath != null
            ? Image.file(File(imagePath), fit: BoxFit.contain)
            : const SizedBox.shrink(),
      ),
    );
  }
}
