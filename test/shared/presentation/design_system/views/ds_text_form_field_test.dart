import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/shared/presentation/design_system/views/ds_text_form_field.dart';

Future<void> _pumpField(
  WidgetTester tester, {
  TextEditingController? controller,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  bool obscureText = false,
  String labelText = 'Email',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DSTextFormField(
          controller: controller ?? TextEditingController(),
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          labelText: labelText,
        ),
      ),
    ),
  );
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required GlobalKey<FormState> formKey,
  required String? Function(String?) validator,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: DSTextFormField(
            controller: TextEditingController(),
            validator: validator,
            labelText: 'Email',
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the label and initial controller value', (tester) async {
    final controller = TextEditingController(text: 'ana@example.com');
    addTearDown(controller.dispose);

    await _pumpField(tester, controller: controller);

    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
  });

  testWidgets('updates the controller when text is entered', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pumpField(tester, controller: controller);

    await tester.enterText(find.byType(TextFormField), 'ana@example.com');

    expect(controller.text, 'ana@example.com');
  });

  testWidgets('passes obscureText to the underlying text field', (
    tester,
  ) async {
    await _pumpField(tester, obscureText: true, labelText: 'Password');

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
  });

  testWidgets('passes keyboardType to the underlying text field', (
    tester,
  ) async {
    await _pumpField(tester, keyboardType: TextInputType.emailAddress);

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).keyboardType,
      TextInputType.emailAddress,
    );
  });

  testWidgets('shows the validator message when the form is invalid', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();

    await _pumpForm(
      tester,
      formKey: formKey,
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();

    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('does not show a validator message for valid input', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();

    await _pumpForm(
      tester,
      formKey: formKey,
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
    );
    await tester.enterText(find.byType(TextFormField), 'value');

    expect(formKey.currentState!.validate(), isTrue);
    await tester.pump();

    expect(find.text('Required'), findsNothing);
  });
}
