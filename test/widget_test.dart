// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/movie_log_app.dart';

void main() {
  testWidgets('MovieLog start screen shows title text', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MovieLogApp());

    // Verify that the start screen title is shown.
    expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });
}