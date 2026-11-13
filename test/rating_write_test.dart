import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';

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

RatingDto _rating(int ratingId, int movieId) => RatingDto(
      ratingId: ratingId,
      movieId: movieId,
      score: 4,
      comment: '좋아요',
      createdAt: DateTime.utc(2026, 11, 12),
    );

DioException _error(int statusCode, String code, String message) {
  final options = RequestOptions(path: '/v6');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: {
        'isSuccess': false,
        'code': code,
        'message': message,
        'result': null,
      },
    ),
    type: DioExceptionType.badResponse,
  );
}

// 메모리 안의 평점 목록으로 동작하는 가짜 평점 Service. 쓰기·조회 실패를 주입할 수 있다.
class _FakeRatingApiService extends RatingApiService {
  _FakeRatingApiService(List<RatingDto> initial)
      : ratings = [...initial],
        super(Dio());

  final List<RatingDto> ratings;
  int fetchCalls = 0;
  DioException? writeError;
  bool failNextFetch = false;
  final Set<int> failingDeletes = {};
  CreateRatingRequest? lastCreate;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    fetchCalls++;
    if (failNextFetch) {
      failNextFetch = false;
      throw DioException(
        requestOptions: RequestOptions(path: '/v6/members/$memberId/ratings'),
        type: DioExceptionType.connectionError,
      );
    }
    return [...ratings];
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final error = writeError;
    if (error != null) throw error;
    lastCreate = request;
  }

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    final error = writeError;
    if (error != null) throw error;
  }

  @override
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final error = writeError;
    if (error != null) throw error;
    if (failingDeletes.contains(ratingId)) {
      throw _error(404, 'COMMON404', '존재하지 않는 평점입니다.');
    }
    ratings.removeWhere((r) => r.ratingId == ratingId);
  }
}

class _FakeTmdbMovieService extends TmdbMovieService {
  _FakeTmdbMovieService() : super(Dio());

  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async => _movie(movieId);
}

// 서버 대신 요청을 가로채 정해진 상태 코드·본문을 돌려주는 Dio
Dio _dio(int statusCode, Object? data, List<RequestOptions> captured) {
  return Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured.add(options);
          handler.resolve(
            Response(requestOptions: options, statusCode: statusCode, data: data),
          );
        },
      ),
    );
}

void main() {
  group('요청 Model', () {
    test('등록 요청은 빈 코멘트를 키째 빼고, 수정 요청은 comment를 항상 보낸다', () {
      expect(
        const CreateRatingRequest(movieId: 550, score: 4, comment: '  ').toJson(),
        {'movieId': 550, 'score': 4},
      );
      expect(
        const CreateRatingRequest(movieId: 550, score: 4, comment: ' 좋아요 ')
            .toJson(),
        {'movieId': 550, 'score': 4, 'comment': '좋아요'},
      );
      expect(
        const UpdateRatingRequest(score: 3, comment: null).toJson(),
        {'score': 3, 'comment': null},
      );
    });

    test('서버 평점은 1~5 정수만 허용한다', () {
      expect(validateServerScore(4), 4);
      expect(() => validateServerScore(3.5), throwsArgumentError);
      expect(() => validateServerScore(0), throwsArgumentError);
    });
  });

  group('RatingApiService 쓰기', () {
    test('등록은 /v6/members/{memberId}/ratings에 POST하고 201을 성공으로 본다', () async {
      final captured = <RequestOptions>[];
      final service = RatingApiService(_dio(201, {
        'isSuccess': true,
        'code': 'COMMON201',
        'message': '평점 등록에 성공했습니다.',
        'result': 12,
      }, captured));

      await service.createRating(
        memberId: 42,
        request: const CreateRatingRequest(movieId: 550, score: 5),
      );

      expect(captured.single.method, 'POST');
      expect(captured.single.uri.path, '/v6/members/42/ratings');
      expect(captured.single.data, {'movieId': 550, 'score': 5});
    });

    test('삭제 204는 본문이 없어도 파싱하지 않고 성공한다', () async {
      final captured = <RequestOptions>[];
      final service = RatingApiService(_dio(204, null, captured));

      await service.deleteRating(memberId: 42, ratingId: 12);

      expect(captured.single.method, 'DELETE');
      expect(captured.single.uri.path, '/v6/members/42/ratings/12');
    });

    test('쓰기 오류 문구는 서버 message, 재조회는 403·404일 때만', () {
      final notFound = _error(404, 'COMMON404', '존재하지 않는 평점입니다.');
      final conflict = _error(409, 'COMMON409', '이미 이 영화에 평점을 남기셨습니다.');

      expect(writeErrorMessage(notFound), '존재하지 않는 평점입니다.');
      expect(writeErrorMessage(conflict), '이미 이 영화에 평점을 남기셨습니다.');
      expect(shouldRefreshAfterRatingError(notFound), isTrue);
      expect(
        shouldRefreshAfterRatingError(
          _error(403, 'COMMON403', '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
        ),
        isTrue,
      );
      expect(shouldRefreshAfterRatingError(conflict), isFalse);
    });

    test('공통 형식이 아닌 403·404 본문도 status로 재조회 대상이 된다', () {
      for (final status in [403, 404]) {
        final options = RequestOptions(path: '/v6');
        final error = DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: status,
            data: '<html>Not Found</html>',
          ),
          type: DioExceptionType.badResponse,
        );
        expect(shouldRefreshAfterRatingError(error), isTrue);
      }
    });
  });

  group('MovieDetailViewModel 등록', () {
    test('선택한 TMDB 영화 id를 movieId로 보내고 success', () async {
      final service = _FakeRatingApiService(const []);
      final viewModel = MovieDetailViewModel(service, 42, _movie(550));

      await viewModel.createRating(score: 4, comment: '좋아요');

      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(service.lastCreate?.movieId, 550);
      expect(service.lastCreate?.score, 4);
    });

    test('409는 서버 message로 error, 회원가입 전에는 요청하지 않는다', () async {
      final service = _FakeRatingApiService(const [])
        ..writeError = _error(409, 'COMMON409', '이미 이 영화에 평점을 남기셨습니다.');
      final viewModel = MovieDetailViewModel(service, 42, _movie(550));

      await viewModel.createRating(score: 4);
      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.submitMessage, '이미 이 영화에 평점을 남기셨습니다.');

      final noMember = MovieDetailViewModel(service, null, _movie(550));
      expect(noMember.canRate, isFalse);
      await noMember.createRating(score: 4);
      expect(noMember.submitMessage, '먼저 회원가입을 완료해 주세요.');
    });
  });

  group('MyRatingsViewModel 수정·삭제', () {
    test('수정 성공 뒤 목록을 다시 조회한다', () async {
      final service = _FakeRatingApiService([_rating(1, 550)]);
      final viewModel =
          MyRatingsViewModel(service, _FakeTmdbMovieService(), 42);
      await viewModel.load();

      await viewModel.updateRating(ratingId: 1, score: 5, comment: null);

      expect(service.fetchCalls, 2);
      expect(viewModel.refreshWarning, isNull);
    });

    test('수정 400은 SubmitFailure(서버 문구)이고 목록을 다시 읽지 않는다', () async {
      final service = _FakeRatingApiService([_rating(1, 550)])
        ..writeError = _error(400, 'COMMON400', '별점은 5점 이하여야 합니다.');
      final viewModel =
          MyRatingsViewModel(service, _FakeTmdbMovieService(), 42);
      await viewModel.load();

      await expectLater(
        viewModel.updateRating(ratingId: 1, score: 5),
        throwsA(
          isA<SubmitFailure>()
              .having((e) => e.message, 'message', '별점은 5점 이하여야 합니다.'),
        ),
      );
      expect(service.fetchCalls, 1);
    });

    test('삭제 404는 SubmitFailure이고 목록을 다시 읽어 서버와 맞춘다', () async {
      final service = _FakeRatingApiService([_rating(1, 550)])
        ..writeError = _error(404, 'COMMON404', '존재하지 않는 평점입니다.');
      final viewModel =
          MyRatingsViewModel(service, _FakeTmdbMovieService(), 42);
      await viewModel.load();

      await expectLater(
        viewModel.deleteRating(1),
        throwsA(isA<SubmitFailure>()),
      );
      expect(service.fetchCalls, 2);
    });

    test('저장은 성공했지만 재조회만 실패하면 쓰기 실패로 던지지 않고 경고만 남긴다', () async {
      final service = _FakeRatingApiService([_rating(1, 550)]);
      final viewModel =
          MyRatingsViewModel(service, _FakeTmdbMovieService(), 42);
      await viewModel.load();

      service.failNextFetch = true;
      await viewModel.updateRating(ratingId: 1, score: 3, comment: '수정');

      expect(viewModel.status, MyRatingsLoadStatus.error);
      expect(viewModel.refreshWarning, contains('저장은 완료됐지만'));

      // 조회만 다시 시도하면 경고가 사라진다.
      await viewModel.load();
      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.refreshWarning, isNull);
    });

    test('마지막 항목을 삭제하면 Empty', () async {
      final service = _FakeRatingApiService([_rating(1, 550)]);
      final viewModel =
          MyRatingsViewModel(service, _FakeTmdbMovieService(), 42);
      await viewModel.load();

      await viewModel.deleteRating(1);

      expect(viewModel.status, MyRatingsLoadStatus.empty);
    });
  });

  group('MyRatingsViewModel 다중 삭제 (Challenge)', () {
    test('일부만 실패하면 성공한 항목만 사라지고 실패한 항목은 선택이 남는다', () async {
      final service = _FakeRatingApiService(
        [_rating(3, 13), _rating(2, 680), _rating(1, 550)],
      )..failingDeletes.add(2);
      final viewModel =
          MyRatingsViewModel(service, _FakeTmdbMovieService(), 42);
      await viewModel.load();

      viewModel
        ..startSelecting()
        ..toggleSelected(3)
        ..toggleSelected(2);
      final failed = await viewModel.deleteSelectedRatings();

      expect(failed, 1);
      expect(viewModel.isDeletingSelected, isFalse);
      expect(viewModel.isSelecting, isTrue);
      expect(viewModel.selectedRatingIds, {2});
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [2, 1]);
    });

    test('모두 성공하면 선택 모드를 끝낸다', () async {
      final service =
          _FakeRatingApiService([_rating(2, 680), _rating(1, 550)]);
      final viewModel =
          MyRatingsViewModel(service, _FakeTmdbMovieService(), 42);
      await viewModel.load();

      viewModel
        ..startSelecting()
        ..toggleSelected(2)
        ..toggleSelected(1);
      final failed = await viewModel.deleteSelectedRatings();

      expect(failed, 0);
      expect(viewModel.isSelecting, isFalse);
      expect(viewModel.status, MyRatingsLoadStatus.empty);
    });
  });
}
