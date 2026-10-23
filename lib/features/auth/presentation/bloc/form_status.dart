import '../../domain/entities/user.dart';

sealed class FormStatus {
  const FormStatus();
}

final class FormInitial extends FormStatus {
  const FormInitial();
}

final class FormSubmitting extends FormStatus {
  const FormSubmitting();
}

final class FormSuccess extends FormStatus {
  final User user;

  const FormSuccess(this.user);
}

final class FormFailure extends FormStatus {
  final String message;

  const FormFailure(this.message);
}
