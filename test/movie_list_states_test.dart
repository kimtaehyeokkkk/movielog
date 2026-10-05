import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/widgets/movie_grid.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('Loading', () {
    testWidgets('Skeleton 카드가 표시되고 접근성 라벨이 있다', (tester) async {
      await tester.pumpWidget(_wrap(const MovieListLoading()));

      expect(find.byType(GridView), findsOneWidget);
      expect(find.bySemanticsLabel('영화를 불러오는 중입니다.'), findsOneWidget);
    });
  });

  group('Empty', () {
    testWidgets('안내 문구가 표시된다', (tester) async {
      await tester.pumpWidget(_wrap(const MovieListEmpty()));

      expect(find.text('조건에 맞는 영화가 없습니다.'), findsOneWidget);
    });
  });

  group('Error', () {
    testWidgets('오류 문구와 다시 시도 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(_wrap(MovieListError(onRetry: () {})));

      expect(find.text('영화를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('다시 시도 버튼을 누르면 onRetry가 호출된다', (tester) async {
      var retryCount = 0;

      await tester.pumpWidget(
        _wrap(MovieListError(onRetry: () => retryCount++)),
      );
      await tester.tap(find.text('다시 시도'));
      await tester.pump();

      expect(retryCount, 1);
    });

    testWidgets('Timeout이면 지연 안내 문구가 표시된다', (tester) async {
      await tester.pumpWidget(
        _wrap(MovieListError(onRetry: () {}, isTimeout: true)),
      );

      expect(find.text('응답이 지연되고 있습니다.'), findsOneWidget);
      expect(find.text('영화를 불러오지 못했습니다.'), findsNothing);
    });

    testWidgets('내부 Exception 정보는 화면에 노출되지 않는다', (tester) async {
      await tester.pumpWidget(_wrap(MovieListError(onRetry: () {})));

      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('StackTrace'), findsNothing);
    });
  });

  group('Success', () {
    testWidgets('영화 제목이 Grid에 표시된다', (tester) async {
      await tester.pumpWidget(_wrap(MovieGrid(movies: movies.take(2).toList())));

      expect(find.text('별빛 아래 우리'), findsOneWidget);
      expect(find.text('우주의 끝에서'), findsOneWidget);
    });
  });
}