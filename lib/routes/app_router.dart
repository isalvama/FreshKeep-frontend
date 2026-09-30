import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/service_locator.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/pages/home_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/products/presentation/bloc/edit_product_bloc.dart';
import '../features/products/presentation/pages/edit_product_page.dart';
import '../features/shopping_receipt/domain/entities/persisted_product.dart';
import '../features/shopping_receipt/presentation/pages/confirm_image_page.dart';
import '../features/shopping_receipt/presentation/pages/receipt_error_page.dart';
import '../features/shopping_receipt/presentation/pages/receipt_processing_page.dart';
import '../features/shopping_receipt/presentation/pages/receipt_reprocessed_page.dart';
import '../features/shopping_receipt/presentation/pages/receipt_results_page.dart';
import '../features/shopping_receipt/presentation/pages/space_picker_page.dart';
import '../features/space_overview/presentation/bloc/space_overview_bloc.dart';
import '../features/space_overview/presentation/pages/space_overview_page.dart';
import '../features/spaces/domain/entities/space.dart';
import '../features/spaces/presentation/bloc/join_space_bloc.dart';
import '../features/spaces/presentation/pages/create_space_result.dart';
import '../features/spaces/presentation/pages/join_space_page.dart';
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
      GoRoute(
        path: '/process-receipt/space',
        builder: (context, state) => const SpacePickerPage(),
      ),
      GoRoute(
        path: '/process-receipt/confirm-image',
        builder: (context, state) => const ConfirmImagePage(),
      ),
      GoRoute(
        path: '/process-receipt/processing',
        builder: (context, state) => const ReceiptProcessingPage(),
      ),
      GoRoute(
        path: '/process-receipt/error',
        builder: (context, state) => const ReceiptErrorPage(),
      ),
      GoRoute(
        path: '/process-receipt/results',
        builder: (context, state) => const ReceiptResultsPage(),
      ),
      GoRoute(
        path: '/process-receipt/reprocessed-results',
        builder: (context, state) => const ReceiptReprocessedPage(),
      ),
      GoRoute(
        path: '/space-overview/:spaceId',
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          final space = state.extra as Space?;
          return BlocProvider(
            create: (_) =>
                getIt<SpaceOverviewBloc>()
                  ..add(SpaceOverviewRequested(spaceId)),
            child: SpaceOverviewPage(spaceId: spaceId, space: space),
          );
        },
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<JoinSpaceBloc>(),
          child: JoinSpacePage(token: state.uri.queryParameters['token'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/space-overview/:spaceId/products/:productId/edit',
        builder: (context, state) {
          final product = state.extra as PersistedProduct;
          return BlocProvider(
            create: (_) => getIt<EditProductBloc>(param1: product),
            child: const EditProductPage(),
          );
        },
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
