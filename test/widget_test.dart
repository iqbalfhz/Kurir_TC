import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ganti ke app.dart, karena kelas MyApp ada di sini
import 'package:starter_kit/app.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Ensure app root exists
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
