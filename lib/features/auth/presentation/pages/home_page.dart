import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
                if (state.spaces.isEmpty) {
                  return const Center(child: Text('No spaces yet.'));
                }
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
                    );
                  },
                );
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
}
