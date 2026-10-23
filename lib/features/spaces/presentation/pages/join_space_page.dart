import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/join_space_bloc.dart';
import '../bloc/spaces_bloc.dart';

/// Asks the user to confirm before joining the space behind [token], the
/// token of a `freshkeep://join` invitation link.
class JoinSpacePage extends StatelessWidget {
  final String token;

  const JoinSpacePage({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: token.isEmpty
                ? const _Failure(message: 'This invitation link is invalid.')
                : BlocConsumer<JoinSpaceBloc, JoinSpaceState>(
                    listener: _onResult,
                    builder: (context, state) => switch (state.status) {
                      JoinSpaceStatus.initial => _Prompt(token: token),
                      JoinSpaceStatus.failure => _Failure(
                        message: state.errorMessage!,
                      ),
                      // After success or a 409 the page is about to be
                      // replaced, so it keeps showing the spinner.
                      _ => const CircularProgressIndicator(),
                    },
                  ),
          ),
        ),
      ),
    );
  }

  void _onResult(BuildContext context, JoinSpaceState state) {
    final router = GoRouter.of(context);

    switch (state.status) {
      case JoinSpaceStatus.success:
        context.read<SpacesBloc>().add(const SpacesRefreshed());
        router.go('/home');
        router.push('/space-overview/${state.spaceId}');
      case JoinSpaceStatus.alreadyParticipant:
        final messenger = ScaffoldMessenger.of(context);
        router.go('/home');
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      default:
        break;
    }
  }
}

class _Prompt extends StatelessWidget {
  final String token;

  const _Prompt({required this.token});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.group_add,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          "You've been invited to join a space",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () =>
                context.read<JoinSpaceBloc>().add(JoinSpaceSubmitted(token)),
            child: const Text('Join'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  final String message;

  const _Failure({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error, size: 72, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 24),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go to Home'),
          ),
        ),
      ],
    );
  }
}
