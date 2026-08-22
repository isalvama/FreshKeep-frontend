import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/pages/home_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/spaces/presentation/pages/create_space_result.dart';
import '../features/spaces/presentation/pages/new_space_page.dart';
import '../features/spaces/presentation/pages/space_status_page.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter buildAppRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/create-space',
        builder: (context, state) => const NewSpacePage(),
      ),
      GoRoute(
        path: '/create-space/status',
        builder: (context, state) =>
            SpaceStatusPage(result: state.extra as CreateSpaceResult),
      ),
    ],
    redirect: (context, state) {
      final authState = authBloc.state;
      final location = state.matchedLocation;

      if (authState is AuthInitial) {
        return location == '/splash' ? null : '/splash';
      }

      final loggedIn = authState is Authenticated;
      final isAuthRoute = location == '/login' || location == '/register';

      if (!loggedIn) {
        return isAuthRoute ? null : '/login';
      }

      return (isAuthRoute || location == '/splash') ? '/home' : null;
    },
  );
}
