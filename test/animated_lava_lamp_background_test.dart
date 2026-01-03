import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushin_reload/ui/widgets/AnimatedLavaLampBackground.dart';

void main() {
  testWidgets('AnimatedLavaLampBackground renders correctly', (WidgetTester tester) async {
    // Build our widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedLavaLampBackground(
            child: const Text('Test Child'),
          ),
        ),
      ),
    );

    // Verify the widget renders
    expect(find.text('Test Child'), findsOneWidget);
    expect(find.byType(AnimatedLavaLampBackground), findsOneWidget);
  });

  testWidgets('AnimatedLavaLampBackground with custom parameters', (WidgetTester tester) async {
    const testPadding = EdgeInsets.all(16.0);
    const testBorderRadius = 20.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedLavaLampBackground(
            padding: testPadding,
            borderRadius: testBorderRadius,
            child: const Text('Test Child'),
          ),
        ),
      ),
    );

    // Verify the widget renders with custom parameters
    expect(find.text('Test Child'), findsOneWidget);
    expect(find.byType(AnimatedLavaLampBackground), findsOneWidget);
  });
}





