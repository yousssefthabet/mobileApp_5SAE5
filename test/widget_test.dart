// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargi/screens/pages/report_details_page.dart';

void main() {
  testWidgets('ReportDetailsPage renders with given report data', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReportDetailsPage(
          reportId: '#TEST01',
          problemTitle: 'Test Overflowing bin',
          location: 'Test Location',
        ),
      ),
    );

    expect(find.text('Report #TEST01'), findsOneWidget);
    expect(find.text('Test Overflowing bin'), findsOneWidget);
  });
}
