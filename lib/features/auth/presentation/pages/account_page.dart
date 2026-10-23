import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';

/// The signed-in account, and the way out of it. Logging out sends the user
/// to the login page through the router's auth redirect.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final email = state is Authenticated ? state.user.email : null;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Email'),
                  subtitle: Text(email ?? '—'),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthBloc>().add(const LoggedOut()),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
