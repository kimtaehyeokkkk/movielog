import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';

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

// v7 평점 쓰기를 메모리에서 흉내 내는 Service. ratingId별 오류를 주입할 수 있다.
class _FakeRatingApiService extends RatingApiService {
  _FakeRatingApiService() : super(Dio(), Dio());

  int _nextId = 100;
  DioException? createError;
  // DioException 또는 계약과 다른 응답을 흉내 낸 StateError 등
  final Map<int, Object> errorsById = {};
  CreateRatingRequest? lastCreate;
  UpdateRatingRequest? lastUpdate;
  final deleted = <int>[];

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final error = createError;
    if (error != null) throw error;
    lastCreate = request;
    return ratingDto(_nextId++, request.movieId,
        score: request.score, comment: request.comment);
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    final error = errorsById[ratingId];
    if (error != null) throw error;
    lastUpdate = request;
    return ratingDto(ratingId, 550,
        score: request.score, comment: request.comment);
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    final error = errorsById[ratingId];
    if (error != null) throw error;
    deleted.add(ratingId);
  }
}

class _FakeTmdbMovieService extends TmdbMovieService {
  _FakeTmdbMovieService() : super(Dio());

  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async => _movie(movieId);
}

class _Fixture {
  _Fixture._(this.auth, this.storage, this.sessionRatings, this.service);

  static Future<_Fixture> create() async {
    final storage = MemoryTokenStorage('token-a');
    final auth = await signedInAuth(storage: storage);
    return _Fixture._(auth, storage, SessionRatings(auth),
        _FakeRatingApiService());
  }

  final AuthViewModel auth;
  final MemoryTokenStorage storage;
  final SessionRatings sessionRatings;
  final _FakeRatingApiService service;

  void seed(List<RatingDto> ratings) {
    for (final rating in ratings.reversed) {
      sessionRatings.add(rating, sessionVersion: auth.sessionVersion);
    }
  }

  MyRatingsViewModel myRatings() => MyRatingsViewModel(
        service,
        _FakeTmdbMovieService(),
        sessionRatings,
        auth,
      );

  MovieDetailViewModel detail(int movieId) =>
      MovieDetailViewModel(service, auth, sessionRatings, _movie(movieId));
}

void main() {
  group('MovieDetailViewModel 등록 (v7)', () {
    test('body에 memberId 없이 TMDB id를 보내고, 등록 result를 세션 목록에 넣는다', () async {
      final f = await _Fixture.create();
      final viewModel = f.detail(550);

      await viewModel.createRating(score: 4, comment: '좋아요');

      expect(f.service.lastCreate?.toJson(),
          {'movieId': 550, 'score': 4, 'comment': '좋아요'});
      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(viewModel.savedScore, 4);
      expect(f.sessionRatings.items.single.movieId, 550);
    });

    test('RATING409_1은 서버 message로 error, 로그인은 유지', () async {
      final f = await _Fixture.create();
      f.service.createError =
          apiError(409, 'RATING409_1', '이미 이 영화에 평점을 남기셨습니다.');
      final viewModel = f.detail(550);

      await viewModel.createRating(score: 4);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.submitMessage, '이미 이 영화에 평점을 남기셨습니다.');
      expect(f.auth.status, AuthStatus.signedIn);
    });

    test('AUTH401_4면 세션을 정리하고 만료 안내를 켠다', () async {
      final f = await _Fixture.create();
      f.service.createError = apiError(401, 'AUTH401_4', '토큰이 만료되었습니다.');
      final viewModel = f.detail(550);

      await viewModel.createRating(score: 4);

      expect(f.auth.status, AuthStatus.signedOut);
      expect(f.auth.sessionExpired, isTrue);
      expect(f.storage.token, isNull);
      expect(viewModel.submitMessage, contains('로그인이 만료됐어요'));
    });
  });

  group('MyRatingsViewModel 수정·삭제 (v7)', () {
    test('수정은 score·comment를 함께 보내고, result로 목록을 바로 갱신한다', () async {
      final f = await _Fixture.create();
      f.seed([ratingDto(1, 550, score: 3, comment: '처음')]);
      final viewModel = f.myRatings();
      await viewModel.load();

      await viewModel.updateRating(ratingId: 1, score: 5, comment: null);
      await Future<void>.delayed(Duration.zero);

      expect(f.service.lastUpdate?.toJson(), {'score': 5, 'comment': null});
      expect(viewModel.ratings.single.rating.score, 5);
      expect(viewModel.ratings.single.rating.comment, isNull);
    });

    test('RATING403_1은 안내만 하고 로그아웃·목록 변경을 하지 않는다', () async {
      final f = await _Fixture.create();
      f.seed([ratingDto(1, 550)]);
      f.service.errorsById[1] = apiError(
          403, 'RATING403_1', '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.');
      final viewModel = f.myRatings();
      await viewModel.load();

      await expectLater(
        viewModel.updateRating(ratingId: 1, score: 5),
        throwsA(isA<SubmitFailure>().having(
            (e) => e.message, 'message', contains('본인이 작성한 평점만'))),
      );

      expect(f.auth.status, AuthStatus.signedIn);
      expect(viewModel.ratings, hasLength(1));
    });

    test('RATING404_1은 안내하고 목록에서 그 평점을 뺀다', () async {
      final f = await _Fixture.create();
      f.seed([ratingDto(1, 550), ratingDto(2, 13)]);
      f.service.errorsById[1] =
          apiError(404, 'RATING404_1', '해당 평점을 찾을 수 없습니다.');
      final viewModel = f.myRatings();
      await viewModel.load();

      await expectLater(viewModel.deleteRating(1), throwsA(isA<SubmitFailure>()));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.ratings.map((e) => e.rating.ratingId), [2]);
    });

    test('삭제 중 AUTH401_2면 세션을 정리하고 목록도 비운다', () async {
      final f = await _Fixture.create();
      f.seed([ratingDto(1, 550)]);
      f.service.errorsById[1] = apiError(401, 'AUTH401_2', '로그인이 필요한 요청입니다.');
      final viewModel = f.myRatings();
      await viewModel.load();

      await expectLater(viewModel.deleteRating(1), throwsA(isA<SubmitFailure>()));

      expect(f.auth.status, AuthStatus.signedOut);
      expect(f.sessionRatings.items, isEmpty);
    });

    test('마지막 평점을 삭제하면 Empty', () async {
      final f = await _Fixture.create();
      f.seed([ratingDto(1, 550)]);
      final viewModel = f.myRatings();
      await viewModel.load();

      await viewModel.deleteRating(1);
      await Future<void>.delayed(Duration.zero);

      expect(f.service.deleted, [1]);
      expect(viewModel.status, MyRatingsLoadStatus.empty);
    });
  });

  group('MyRatingsViewModel 다중 삭제 (Challenge)', () {
    test('일부만 실패하면 실패한 항목만 선택에 남기고 실패 개수를 돌려준다', () async {
      final f = await _Fixture.create();
      f.seed([ratingDto(1, 550), ratingDto(2, 13), ratingDto(3, 680)]);
      f.service.errorsById[2] = networkError();
      final viewModel = f.myRatings();
      await viewModel.load();

      viewModel.startSelecting();
      viewModel.toggleSelected(1);
      viewModel.toggleSelected(2);
      final failed = await viewModel.deleteSelectedRatings();
      await Future<void>.delayed(Duration.zero);

      expect(failed, 1);
      expect(viewModel.selectedRatingIds, {2});
      expect(viewModel.isSelecting, isTrue);
      expect(viewModel.isDeletingSelected, isFalse);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [2, 3]);
    });

    test('Dio가 아닌 오류(예상 밖 응답)도 그 항목만 실패로 세고 다음 항목을 계속 지운다', () async {
      final f = await _Fixture.create();
      f.seed([ratingDto(1, 550), ratingDto(2, 13), ratingDto(3, 680)]);
      f.service.errorsById[1] = StateError('예상하지 못한 삭제 응답: 204');
      final viewModel = f.myRatings();
      await viewModel.load();

      viewModel.startSelecting();
      viewModel.toggleSelected(1);
      viewModel.toggleSelected(2);
      viewModel.toggleSelected(3);
      final failed = await viewModel.deleteSelectedRatings();
      await Future<void>.delayed(Duration.zero);

      expect(failed, 1);
      expect(f.service.deleted, [2, 3]);
      expect(viewModel.selectedRatingIds, {1});
      expect(viewModel.isDeletingSelected, isFalse);
    });

    test('모두 성공하면 선택 모드를 끝낸다', () async {
      final f = await _Fixture.create();
      f.seed([ratingDto(1, 550), ratingDto(2, 13)]);
      final viewModel = f.myRatings();
      await viewModel.load();

      viewModel.startSelecting();
      viewModel.toggleSelected(1);
      viewModel.toggleSelected(2);
      final failed = await viewModel.deleteSelectedRatings();
      await Future<void>.delayed(Duration.zero);

      expect(failed, 0);
      expect(viewModel.isSelecting, isFalse);
      expect(viewModel.status, MyRatingsLoadStatus.empty);
    });
  });

  group('SessionRatings', () {
    test('로그아웃하면 이전 세션 평점을 비우고, 이전 세션의 늦은 응답은 넣지 않는다', () async {
      final f = await _Fixture.create();
      final oldVersion = f.auth.sessionVersion;
      f.seed([ratingDto(1, 550)]);

      await f.auth.logout();
      await f.auth.login('b@umc.com', 'Password1!');
      f.sessionRatings.add(ratingDto(9, 13), sessionVersion: oldVersion);

      expect(f.sessionRatings.items, isEmpty);
    });
  });
}
