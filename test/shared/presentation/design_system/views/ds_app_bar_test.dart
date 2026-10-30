import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/shared/presentation/design_system/views/ds_app_bar.dart';
import 'package:fresh_keep_frontend/shared/presentation/theme/dimens.dart';

final _backButton = find.descendant(
  of: find.byType(AppBar),
  matching: find.byType(IconButton),
);

Future<void> _pump(WidgetTester tester, DSAppBar appBar) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(appBar: appBar)));

/// Opens a second page with [appBar] on top of a first page, so the app bar
/// has a route to pop back to.
Future<void> _pumpOnPushedPage(WidgetTester tester, DSAppBar appBar) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => Scaffold(appBar: appBar)),
            ),
            child: const Text('First page'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('First page'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the title in title case by default', (tester) async {
    await _pump(tester, const DSAppBar(title: 'log in'));

    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets(
    'shows the title without title case when titleInTitleCase is set to false',
    (tester) async {
      await _pump(
        tester,
        const DSAppBar(title: 'log in', titleInTitleCase: false),
      );

      expect(find.text('log in'), findsOneWidget);
    },
  );

  testWidgets('has no back button by default', (tester) async {
    await _pump(tester, const DSAppBar(title: 'Log In'));

    expect(_backButton, findsNothing);
  });

  testWidgets('shows a back button when back is enabled', (tester) async {
    await _pump(tester, const DSAppBar(title: 'Log In', backEnabled: true));

    expect(_backButton, findsOneWidget);
  });

  testWidgets('tapping back calls onBack when one is given', (tester) async {
    var backPressed = 0;
    await _pumpOnPushedPage(
      tester,
      DSAppBar(title: 'Log In', backEnabled: true, onBack: () => backPressed++),
    );

    await tester.tap(_backButton);
    await tester.pumpAndSettle();

    expect(backPressed, 1);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('tapping back pops the page when no onBack is given', (
    tester,
  ) async {
    await _pumpOnPushedPage(
      tester,
      const DSAppBar(title: 'Log In', backEnabled: true),
    );

    await tester.tap(_backButton);
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsNothing);
    expect(find.text('First page'), findsOneWidget);
  });

  testWidgets('has no back button on a pushed page when back is disabled', (
    tester,
  ) async {
    await _pumpOnPushedPage(tester, const DSAppBar(title: 'Log In'));

    expect(_backButton, findsNothing);
  });

  test('has the design system app bar height', () {
    expect(
      const DSAppBar(title: 'Log In').preferredSize.height,
      Dimens.appBarHeight,
    );
  });
}
