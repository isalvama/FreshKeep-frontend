import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final email = state is Authenticated ? state.user.email : null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(email != null ? 'Logged in as $email' : 'Logged in'),
                const SizedBox(height: 24),
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
    );
  }
}
