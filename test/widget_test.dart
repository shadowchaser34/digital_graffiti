import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:digital_graffiti_wall/screens/home_screen.dart';

void main() {
  testWidgets('Home screen boots with poster-aware overlay controls', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: HomeScreen())));
    await tester.pump();

    expect(find.text('Digital Graffiti Wall'), findsOneWidget);
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.emoji_food_beverage), findsOneWidget);
  });
}
