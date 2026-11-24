import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/movie_record_models.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/movie_record_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import 'support/fake_auth.dart';

TmdbMovieDto _movie(int id) => TmdbMovieDto(
      id: id,
      title: '영화 $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      releaseDate: null,
      genreIds: const [],
      voteAverage: 0,
      popularity: 0,
    );

class _FakeRatingApi extends RatingApiService {
  _FakeRatingApi() : super(Dio(), Dio());

  CreateRatingRequest? lastCreate;

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    lastCreate = request;
    return ratingDto(1, request.movieId, score: request.score);
  }
}

class _FakeMovieRecordApi extends MovieRecordApiService {
  _FakeMovieRecordApi() : super(Dio());

  CreateMovieRecordRequest? last;
  DioException? error;

  @override
  Future<MovieRecordResult> saveMovieRecord(
    CreateMovieRecordRequest request,
  ) async {
    final error = this.error;
    if (error != null) throw error;
    last = request;
    return MovieRecordResult(
      rating: ratingDto(2, request.movieId, score: request.score),
    );
  }
}

void main() {
  test('요청 body: movieId·score·addToFavorites 필수, 빈 코멘트는 생략', () {
    expect(
      const CreateMovieRecordRequest(
        movieId: 550,
        score: 3,
        comment: '  ',
        addToFavorites: false,
      ).toJson(),
      {'movieId': 550, 'score': 3, 'addToFavorites': false},
    );
  });

  test('응답의 favorite이 null이어도 정상으로 읽는다', () {
    final result = MovieRecordResult.fromJson({
      'rating': {
        'ratingId': 9,
        'movieId': 550,
        'score': 3,
        'comment': null,
        'createdAt': '2026-11-20T00:00:00.000Z',
        'updatedAt': '2026-11-20T00:00:00.000Z',
      },
      'favorite': null,
    });
    expect(result.rating.ratingId, 9);
    expect(result.favorite, isNull);
  });

  group('MovieDetailViewModel.saveRating (Challenge)', () {
    Future<(MovieDetailViewModel, _FakeRatingApi, _FakeMovieRecordApi, SessionRatings)>
        create() async {
      final auth = await signedInAuth();
      final ratingApi = _FakeRatingApi();
      final recordApi = _FakeMovieRecordApi();
      final sessionRatings = SessionRatings(auth);
      final vm = MovieDetailViewModel(
        ratingApi,
        recordApi,
        auth,
        sessionRatings,
        _movie(550),
      );
      return (vm, ratingApi, recordApi, sessionRatings);
    }

    test('즐겨찾기하지 않은 영화는 movie-records로 한 번에 저장', () async {
      final (vm, ratingApi, recordApi, sessionRatings) = await create();

      await vm.saveRating(
        score: 4,
        comment: '좋아요',
        addToFavorites: true,
        alreadyFavorite: false,
      );

      expect(recordApi.last?.toJson(), {
        'movieId': 550,
        'score': 4,
        'comment': '좋아요',
        'addToFavorites': true,
      });
      expect(ratingApi.lastCreate, isNull);
      expect(vm.submitStatus, SubmitStatus.success);
      expect(sessionRatings.items.single.ratingId, 2);
    });

    test('이미 즐겨찾기한 영화는 평점 API로 평점만 저장', () async {
      final (vm, ratingApi, recordApi, _) = await create();

      await vm.saveRating(
        score: 5,
        addToFavorites: false,
        alreadyFavorite: true,
      );

      expect(ratingApi.lastCreate?.movieId, 550);
      expect(recordApi.last, isNull);
    });

    test('409·회원 없음은 Dialog를 닫고, COMMON400·네트워크는 Dialog를 유지', () async {
      final (vm, _, recordApi, _) = await create();

      for (final (error, closes) in [
        (apiError(409, 'RATING409_1', '이미 이 영화에 평점을 남기셨습니다.'), true),
        (apiError(409, 'FAVORITE409_1', '이미 이 영화를 즐겨찾기하셨습니다.'), true),
        (apiError(404, 'MEMBER404_1', '해당 회원을 찾을 수 없습니다.'), true),
        (apiError(400, 'COMMON400', '별점은 5점 이하여야 합니다.'), false),
        (networkError(), false),
      ]) {
        recordApi.error = error;
        await vm.saveRating(
          score: 3,
          addToFavorites: true,
          alreadyFavorite: false,
        );
        expect(vm.submitStatus, SubmitStatus.error);
        expect(vm.submitClosesDialog, closes, reason: '$error');
      }
    });
  });

  group('RatingDialog (Challenge)', () {
    Future<void> openDialog(
      WidgetTester tester, {
      required bool showAddToFavorite,
      required Future<void> Function(int, String?, bool) onSubmit,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => RatingDialog(
                    initialScore: 3, // 별 3개를 고른 상태에서 시작
                    showAddToFavorite: showAddToFavorite,
                    onSubmit: onSubmit,
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    testWidgets('체크박스는 평점 남기기에서만 보이고, 체크하면 addToFavorites가 true',
        (tester) async {
      bool? received;
      await openDialog(
        tester,
        showAddToFavorite: true,
        onSubmit: (score, comment, addToFavorites) async {
          received = addToFavorites;
        },
      );

      expect(find.text('즐겨찾기에도 추가'), findsOneWidget);
      await tester.tap(find.text('즐겨찾기에도 추가'));
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(received, isTrue);
      expect(find.byType(RatingDialog), findsNothing);
    });

    testWidgets('평점 수정처럼 숨긴 경우 체크박스가 없다', (tester) async {
      await openDialog(
        tester,
        showAddToFavorite: false,
        onSubmit: (_, _, _) async {},
      );
      expect(find.text('즐겨찾기에도 추가'), findsNothing);
    });

    testWidgets('closeDialog 실패는 Dialog를 닫고 Snackbar, 아니면 Dialog 안에 문구',
        (tester) async {
      var closes = false;
      await openDialog(
        tester,
        showAddToFavorite: true,
        onSubmit: (_, _, _) async =>
            throw SubmitFailure('이미 이 영화에 평점을 남기셨습니다.', closeDialog: closes),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();
      // Dialog 유지 + 문구
      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);

      closes = true;
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
