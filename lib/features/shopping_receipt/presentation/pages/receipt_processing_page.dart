import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/shopping_receipt_bloc.dart';

class ReceiptProcessingPage extends StatelessWidget {
  const ReceiptProcessingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<ShoppingReceiptBloc, ShoppingReceiptState>(
        listenWhen: (previous, current) =>
            (previous.status is! ShoppingReceiptProcessSuccess &&
                current.status is ShoppingReceiptProcessSuccess) ||
            (previous.status is! ShoppingReceiptProcessFailure &&
                current.status is ShoppingReceiptProcessFailure),
        listener: (context, state) {
          if (state.status is ShoppingReceiptProcessSuccess) {
            context.push('/process-receipt/results');
          } else if (state.status is ShoppingReceiptProcessFailure) {
            context.push('/process-receipt/error');
          }
        },
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
