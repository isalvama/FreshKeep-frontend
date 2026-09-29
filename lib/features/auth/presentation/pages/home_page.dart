import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../spaces/domain/entities/space.dart';
import '../../../spaces/presentation/bloc/spaces_bloc.dart';
import '../../../spaces/presentation/widgets/creation_bottom_sheet.dart';
import '../bloc/auth_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final email = state is Authenticated ? state.user.email : null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(email != null ? 'Logged in as $email' : 'Logged in'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<AuthBloc>().add(const LoggedOut()),
                      child: const Text('Log out'),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<SpacesBloc, SpacesState>(
              builder: (context, state) {
                switch (state.status) {
                  case SpacesStatus.initial:
                  case SpacesStatus.loading:
                    return const Center(child: CircularProgressIndicator());
                  case SpacesStatus.loadFailure:
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.errorMessage ?? 'Something went wrong.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => context.read<SpacesBloc>().add(
                                const SpacesRequested(),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  case SpacesStatus.loaded:
                    if (state.spaces.isEmpty) {
                      return const Center(child: Text('No spaces yet.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: state.spaces.length,
                      itemBuilder: (_, index) {
                        final space = state.spaces[index];
                        return ListTile(
                          leading: Text(
                            space.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(space.spaceName),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openOverview(context, space),
                        );
                      },
                    );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreationBottomSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Spaces are shared, so another participant may have changed them while
  /// the overview was open: refresh silently once the user comes back.
  Future<void> _openOverview(BuildContext context, Space space) async {
    await context.push('/space-overview/${space.id}', extra: space);
    if (!context.mounted) return;
    context.read<SpacesBloc>().add(const SpacesRefreshed());
  }
}
