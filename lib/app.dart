import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/config/env.dart';
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

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const secureStorage = FlutterSecureStorage();
    final dioClient = DioClient(
      baseUrl: Env.apiBaseUrl,
      secureStorage: secureStorage,
    );
    setupServiceLocator(dio: dioClient.dio);

    final AuthRepository authRepository = AuthRepositoryImpl(
      remoteDataSource: AuthRemoteDataSource(dioClient.dio),
      localDataSource: const AuthLocalDataSource(secureStorage),
    );

    final authBloc = AuthBloc(
      checkAuthStatusUseCase: CheckAuthStatusUseCase(authRepository),
      currentUserUseCase: CurrentUserUseCase(authRepository),
      logoutUseCase: LogoutUseCase(authRepository),
    )..add(const AppStarted());

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<LoginBloc>(
          create: (_) => LoginBloc(
            loginUseCase: LoginUseCase(authRepository),
            authBloc: authBloc,
          ),
        ),
        BlocProvider<RegisterBloc>(
          create: (_) =>
              RegisterBloc(registerUseCase: RegisterUseCase(authRepository)),
        ),
        BlocProvider<SpacesBloc>.value(value: getIt<SpacesBloc>()),
        BlocProvider<CreateSpaceBloc>.value(value: getIt<CreateSpaceBloc>()),
        BlocProvider<ShoppingReceiptBloc>.value(
          value: getIt<ShoppingReceiptBloc>(),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            previous is! Authenticated && current is Authenticated,
        listener: (context, state) {
          context.read<SpacesBloc>().add(const SpacesRequested());
        },
        child: MaterialApp.router(
          routerConfig: buildAppRouter(authBloc),
          theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        ),
      ),
    );
  }
}
