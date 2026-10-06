import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/shared/widgets/loading_animation.dart';

/// The visible text: the message and the dots that aren't transparent.
String _visibleText(WidgetTester tester) {
  final text = tester.widget<Text>(find.byType(Text));
  final root = text.textSpan! as TextSpan;
  final buffer = StringBuffer(root.text ?? '');
  for (final child in root.children!.cast<TextSpan>()) {
    if (child.style?.color != Colors.transparent) buffer.write(child.text);
  }
  return buffer.toString();
}

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  const MaterialApp(
    home: Scaffold(body: Center(child: AnimatedLoadingText('Loading'))),
  ),
);

void main() {
  testWidgets('the dots count up from one to three, then start again', (
    tester,
  ) async {
    await _pump(tester);
    expect(_visibleText(tester), 'Loading.');

    await tester.pump(const Duration(milliseconds: 600));
    expect(_visibleText(tester), 'Loading..');

    await tester.pump(const Duration(milliseconds: 600));
    expect(_visibleText(tester), 'Loading...');

    await tester.pump(const Duration(milliseconds: 600));
    expect(_visibleText(tester), 'Loading.');
  });

  testWidgets('the text keeps the same width as the dots change', (
    tester,
  ) async {
    await _pump(tester);
    final width = tester.getSize(find.byType(Text)).width;

    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.getSize(find.byType(Text)).width, width);
  });

  testWidgets('the text pulses: it fades out and back in', (tester) async {
    await _pump(tester);
    double opacity() => tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(opacity(), 1);

    await tester.pump(const Duration(milliseconds: 800));
    expect(opacity(), closeTo(0.55, 0.01));

    await tester.pump(const Duration(milliseconds: 800));
    expect(opacity(), closeTo(1, 0.01));
  });

  testWidgets('screen readers hear the message once, without the dots', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });
}
