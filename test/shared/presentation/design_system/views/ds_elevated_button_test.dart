import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/shared/presentation/design_system/views/ds_elevated_button.dart';

Future<void> _pump(WidgetTester tester, DSElevatedButton dsElevatedButton) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: dsElevatedButton)));

Future<void> _pumpScaffold(WidgetTester tester, Scaffold scaffold) =>
    tester.pumpWidget(MaterialApp(home: scaffold));

final Finder _loadingProgressIndicator = find.descendant(
  of: find.byType(ElevatedButton),
  matching: find.byType(CircularProgressIndicator),
);

final Finder _button = find.byType(DSElevatedButton);

void main() {
  testWidgets('shows the text in title case by default', (tester) async {
    await _pump(
      tester,
      DSElevatedButton(
        text: 'log in',
        isSubmitting: false,
        submit: (context) {},
      ),
    );

    expect(find.text('Log In'), findsOneWidget);
    expect(_loadingProgressIndicator, findsNothing);
  });

  testWidgets(
    'shows the text without title case when textToTitleCase is set to false',
    (tester) async {
      await _pump(
        tester,
        DSElevatedButton(
          text: 'log in',
          textInTitleCase: false,
          isSubmitting: false,
          submit: (context) {},
        ),
      );

      expect(find.text('log in'), findsOneWidget);
      expect(_loadingProgressIndicator, findsNothing);
    },
  );

  testWidgets('shows a loading progress indicator when isSubmitting is true', (
    tester,
  ) async {
    await _pump(
      tester,
      DSElevatedButton(
        text: 'Log In',
        isSubmitting: true,
        submit: (context) {},
      ),
    );

    expect(_loadingProgressIndicator, findsOneWidget);
    expect(find.text('Log In'), findsNothing);
  });

  testWidgets(
    'shows the text initially and a loading progress indicator after pressing the button',
    (tester) async {
      bool isSubmitting = false;
      await _pumpScaffold(
        tester,
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DSElevatedButton(
              text: 'Log In',
              isSubmitting: isSubmitting,
              submit: (context) => setState(() => isSubmitting = true),
            ),
          ),
        ),
      );
      expect(find.text('Log In'), findsOneWidget);
      expect(_loadingProgressIndicator, findsNothing);

      await tester.tap(_button);
      await tester.pump();

      expect(_loadingProgressIndicator, findsOneWidget);
      expect(find.text('Log In'), findsNothing);
    },
  );

  testWidgets(
    'submit is called when the button is pressed and isSubmitting is false',
    (tester) async {
      int nTimesButtonPressed = 0;

      await _pump(
        tester,
        DSElevatedButton(
          text: 'Log In',
          isSubmitting: false,
          submit: (context) {
            nTimesButtonPressed++;
          },
        ),
      );

      await tester.tap(_button);
      await tester.pump();

      expect(nTimesButtonPressed, 1);
    },
  );

  testWidgets(
    'submit is not called when button is pressed and isSubmitting is true',
    (tester) async {
      int nTimesButtonPressed = 0;
      await _pump(
        tester,
        DSElevatedButton(
          text: 'Log In',
          isSubmitting: true,
          submit: (context) {
            nTimesButtonPressed++;
          },
        ),
      );

      await tester.tap(_button);
      await tester.pump();
      expect(nTimesButtonPressed, 0);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    },
  );
}
