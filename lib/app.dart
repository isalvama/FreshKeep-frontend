import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'core/config/env.dart';
import 'core/deep_links/invitation_link_listener.dart';
import 'core/deep_links/pending_invitation_store.dart';
import 'core/di/service_locator.dart';
import 'core/network/dio_client.dart';
import 'features/auth/data/datasources/auth_local_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/check_auth_status_usecase.dart';
import 'features/auth/domain/usecases/current_user_usecase.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/logout_usecase.dart';
import 'features/auth/domain/usecases/register_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/login_bloc.dart';
import 'features/auth/presentation/bloc/register_bloc.dart';
import 'features/shopping_receipt/presentation/bloc/shopping_receipt_bloc.dart';
import 'features/spaces/presentation/bloc/create_space_bloc.dart';
import 'features/spaces/presentation/bloc/spaces_bloc.dart';
import 'routes/app_router.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthRepository _authRepository;
  late final AuthBloc _authBloc;
  // Built once, so the invitation link listener keeps a stable router.
  late final GoRouter _router;
  InvitationLinkListener? _invitationLinks;

  @override
  void initState() {
    super.initState();
    const secureStorage = FlutterSecureStorage();
    final dioClient = DioClient(
      baseUrl: Env.apiBaseUrl,
      secureStorage: secureStorage,
    );
    setupServiceLocator(dio: dioClient.dio);

    _authRepository = AuthRepositoryImpl(
      remoteDataSource: AuthRemoteDataSource(dioClient.dio),
      localDataSource: const AuthLocalDataSource(secureStorage),
    );

    _authBloc = AuthBloc(
      checkAuthStatusUseCase: CheckAuthStatusUseCase(_authRepository),
      currentUserUseCase: CurrentUserUseCase(_authRepository),
      logoutUseCase: LogoutUseCase(_authRepository),
    )..add(const AppStarted());

    _router = buildAppRouter(
      _authBloc,
      pendingInvitations: getIt<PendingInvitationStore>(),
    );

    // The freshkeep scheme is only registered on Android and iOS.
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (isMobile) {
      _invitationLinks = InvitationLinkListener(
        links: AppLinks().uriLinkStream,
        push: _router.push,
      )..start();
    }
  }

  @override
  void dispose() {
    _invitationLinks?.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _authBloc),
        BlocProvider<LoginBloc>(
          create: (_) => LoginBloc(
            loginUseCase: LoginUseCase(_authRepository),
            authBloc: _authBloc,
          ),
        ),
        BlocProvider<RegisterBloc>(
          create: (_) =>
              RegisterBloc(registerUseCase: RegisterUseCase(_authRepository)),
        ),
        BlocProvider<SpacesBloc>.value(value: getIt<SpacesBloc>()),
        BlocProvider<CreateSpaceBloc>.value(value: getIt<CreateSpaceBloc>()),
        BlocProvider<ShoppingReceiptBloc>.value(
          value: getIt<ShoppingReceiptBloc>(),
        ),
      ],
      child: AuthSessionListener(
        pendingInvitations: getIt<PendingInvitationStore>(),
        child: MaterialApp.router(
          routerConfig: _router,
          theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        ),
      ),
    );
  }
}

/// Loads the spaces on login, and drops a pending invitation on logout.
class AuthSessionListener extends StatelessWidget {
  final PendingInvitationStore pendingInvitations;
  final Widget child;

  const AuthSessionListener({
    super.key,
    required this.pendingInvitations,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          (previous is Authenticated) != (current is Authenticated),
      listener: (context, state) {
        if (state is Authenticated) {
          context.read<SpacesBloc>().add(const SpacesRequested());
        } else {
          pendingInvitations.clear();
        }
      },
      child: child,
    );
  }
}
