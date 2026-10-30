import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/widgets/movie_grid.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

TmdbMovieDto _movie({
  required int id,
  required String title,
  String? releaseDate,
}) {
  return TmdbMovieDto(
    id: id,
    title: title,
    overview: '',
    posterPath: null,
    backdropPath: null,
    releaseDate: releaseDate,
    genreIds: const [28],
    voteAverage: 8.5,
    popularity: 100,
  );
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
    testWidgets('영화 제목과 장르 이름이 Grid에 표시된다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MovieGrid(
            movies: [
              _movie(id: 1, title: '다크 나이트', releaseDate: '2008-07-16'),
              _movie(id: 2, title: '개봉일 없는 영화'),
            ],
            genreNames: const {28: '액션'},
          ),
        ),
      );

      expect(find.text('다크 나이트'), findsOneWidget);
      expect(find.text('개봉일 없는 영화'), findsOneWidget);
      expect(find.text('2008 · 액션'), findsOneWidget);
      // release_date가 없으면 연도 없이 장르만 표시한다.
      expect(find.text('액션'), findsOneWidget);
    });

    testWidgets('poster_path가 null이면 placeholder가 표시된다', (tester) async {
      await tester.pumpWidget(
        _wrap(MovieGrid(movies: [_movie(id: 1, title: '포스터 없음')])),
      );

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });
  });
}