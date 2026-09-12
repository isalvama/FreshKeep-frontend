import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/shopping_receipt_bloc.dart';

class ReceiptErrorPage extends StatelessWidget {
  const ReceiptErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<ShoppingReceiptBloc>().state.status;
    final message = status is ShoppingReceiptProcessFailure
        ? status.message
        : 'Something went wrong.';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
