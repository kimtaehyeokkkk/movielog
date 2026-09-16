import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/movie_log_app.dart';

void main() {
  testWidgets('MovieLog profile screen shows key texts', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MovieLogApp());

    // Verify that the profile screen's key texts are shown.
    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.text('무비러버'), findsOneWidget);
    expect(find.text('프로필 수정'), findsOneWidget);
  });
}