import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/register_usecase.dart';
import 'form_status.dart';

class RegisterSubmitted {
  final String email;
  final String password;

  const RegisterSubmitted({required this.email, required this.password});
}

class RegisterBloc extends Bloc<RegisterSubmitted, FormStatus> {
  final RegisterUseCase registerUseCase;

  RegisterBloc({required this.registerUseCase}) : super(const FormInitial()) {
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
      (user) => emit(FormSuccess(user)),
    );
  }
}
