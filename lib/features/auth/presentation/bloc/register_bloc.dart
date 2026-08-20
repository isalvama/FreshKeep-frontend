import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/register_usecase.dart';
import 'auth_bloc.dart';
import 'form_status.dart';

class RegisterSubmitted {
  final String email;
  final String password;

  const RegisterSubmitted({required this.email, required this.password});
}

class RegisterBloc extends Bloc<RegisterSubmitted, FormStatus> {
  final RegisterUseCase registerUseCase;
  final AuthBloc authBloc;

  RegisterBloc({required this.registerUseCase, required this.authBloc})
      : super(const FormInitial()) {
    on<RegisterSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<FormStatus> emit,
  ) async {
    emit(const FormSubmitting());
    final result = await registerUseCase(event.email, event.password);
    result.match(
      (failure) => emit(FormFailure(failure.message)),
      (user) {
        authBloc.add(LoggedIn(user));
        emit(FormSuccess(user));
      },
    );
  }
}
