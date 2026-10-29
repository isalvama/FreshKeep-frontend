import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/shared/presentation/design_system/views/ds_text_button.dart';

Future<void> _pumpWidget(
  WidgetTester tester, {
  required String text,
  required void Function()? onPressed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DSTextButton(onPressed: onPressed, text: text),
      ),
    ),
  );
}

Future<void> _pumpWidgetWithTextInTitleCaseParam(
  WidgetTester tester, {
  required String text,
  required void Function()? onPressed,
  required bool textInTitleCase,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DSTextButton(
          onPressed: onPressed,
          text: text,
          textInTitleCase: textInTitleCase,
        ),
      ),
    ),
  );
}

final Finder _button = find.byType(DSTextButton);

void main() {
  testWidgets('shows the text in title case as default', (tester) async {
    await _pumpWidget(tester, text: "button text", onPressed: (() => {}));

    expect(find.widgetWithText(DSTextButton, "Button Text"), findsOneWidget);
  });

  testWidgets('shows the text in the same format', (tester) async {
    await _pumpWidgetWithTextInTitleCaseParam(
      tester,
      text: "button text",
      onPressed: (() => {}),
      textInTitleCase: false,
    );

    expect(find.widgetWithText(DSTextButton, "button text"), findsOneWidget);
  });

  testWidgets('onPressed is called when pressing the button text', (
    tester,
  ) async {
    int buttonPressed = 0;
    await _pumpWidget(
      tester,
      text: "button text",
      onPressed: (() => buttonPressed++),
    );

    await tester.tap(_button);

    expect(buttonPressed, 1);
  });
}
