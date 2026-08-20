import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/login_usecase.dart';
import 'auth_bloc.dart';
import 'form_status.dart';

class LoginSubmitted {
  final String email;
  final String password;

  const LoginSubmitted({required this.email, required this.password});
}

class LoginBloc extends Bloc<LoginSubmitted, FormStatus> {
  final LoginUseCase loginUseCase;
  final AuthBloc authBloc;

  LoginBloc({required this.loginUseCase, required this.authBloc})
      : super(const FormInitial()) {
    on<LoginSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<FormStatus> emit,
  ) async {
    emit(const FormSubmitting());
    final result = await loginUseCase(event.email, event.password);
    result.match(
      (failure) => emit(FormFailure(failure.message)),
      (user) {
        authBloc.add(LoggedIn(user));
        emit(FormSuccess(user));
      },
    );
  }
}
