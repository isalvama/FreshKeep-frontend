import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'create_space_result.dart';

class SpaceStatusPage extends StatelessWidget {
  final CreateSpaceResult result;

  const SpaceStatusPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isSuccess = result is CreateSpaceResultSuccess;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  size: 72,
                  color: isSuccess
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  isSuccess
                      ? 'Space created successfully!'
                      : (result as CreateSpaceResultError).message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isSuccess) {
                        context.go('/home');
                      } else {
                        context.go('/create-space');
                      }
                    },
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
