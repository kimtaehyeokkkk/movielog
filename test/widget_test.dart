import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/profile_screen.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:provider/provider.dart';

import 'support/fake_member_service.dart';

void main() {
  testWidgets('MovieLog profile screen shows key texts and my ratings', (
    WidgetTester tester,
  ) async {
    final service = FakeMemberService(
      ratings: [
        RatingDto(
          ratingId: 2,
          movieId: 155,
          score: 4,
          comment: '다시 봐도 명작',
          createdAt: DateTime(2026, 10, 31),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<MyRatingsViewModel>(
          create: (_) => MyRatingsViewModel(service, memberId: 1)..load(),
          child: const ProfileScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.text('무비러버'), findsOneWidget);
    expect(find.text('프로필 수정'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('영화 #155'), 200);
    expect(find.text('다시 봐도 명작'), findsOneWidget);
    expect(find.text('총 1개'), findsOneWidget);
  });
}
