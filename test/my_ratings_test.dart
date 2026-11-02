import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';

RatingDto _rating(int ratingId, int movieId, {String? comment}) {
  return RatingDto(
    ratingId: ratingId,
    movieId: movieId,
    score: 4,
    comment: comment,
    createdAt: DateTime.utc(2026, 11, 1),
  );
}

TmdbMovieDto _movie(int id) {
  return TmdbMovieDto(
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
}

DioException _dioError(int? statusCode) {
  final options = RequestOptions(path: '/test');
  return DioException(
    requestOptions: options,
    response: statusCode == null
        ? null
        : Response(requestOptions: options, statusCode: statusCode),
    type: statusCode == null
        ? DioExceptionType.connectionError
        : DioExceptionType.badResponse,
  );
}

class _FakeRatingApiService extends RatingApiService {
  _FakeRatingApiService(this.result) : super(Dio());

  final Object result; // List<RatingDto> 또는 DioException

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final result = this.result;
    if (result is DioException) throw result;
    return result as List<RatingDto>;
  }
}

// movieId별로 영화·null(404)·네트워크 실패를 돌려주는 TMDB Service
class _FakeTmdbMovieService extends TmdbMovieService {
  _FakeTmdbMovieService({this.notFound = const {}, this.failing = const {}})
      : super(Dio());

  final Set<int> notFound;
  final Set<int> failing;
  final calls = <int>[];

  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async {
    calls.add(movieId);
    if (failing.contains(movieId)) throw _dioError(null);
    if (notFound.contains(movieId)) return null;
    return _movie(movieId);
  }
}

// 서버 대신 요청을 가로채 정해진 응답(또는 오류)을 돌려주는 Dio
Dio _dio({Object? data, int statusCode = 200, List<RequestOptions>? captured}) {
  return Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured?.add(options);
          final response = Response(
            requestOptions: options,
            statusCode: statusCode,
            data: data,
          );
          if (statusCode >= 400) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          } else {
            handler.resolve(response);
          }
        },
      ),
    );
}

void main() {
  group('Service · DTO', () {
    test('중복 확인은 한글·@를 인코딩해 /v5 path로 요청한다', () async {
      final captured = <RequestOptions>[];
      final service =
          MemberCheckService(_dio(data: {'available': false}, captured: captured));

      final nickname = await service.checkNickname(' 영화광 ');
      await service.checkEmail('movie@umc.com');

      expect(nickname, isFalse);
      expect(
        captured[0].uri.path,
        '/v5/members/nickname/%EC%98%81%ED%99%94%EA%B4%91',
      );
      expect(captured[1].uri.path, '/v5/members/email/movie%40umc.com');
    });

    test('평점 배열을 그대로 RatingDto 목록으로 바꾸고 comment null을 허용한다', () async {
      final service = RatingApiService(
        _dio(data: [
          {
            'ratingId': 3,
            'movieId': 13,
            'score': 3,
            'comment': null,
            'createdAt': '2026-11-01T19:00:27.956Z',
            'updatedAt': '2026-11-01T19:00:27.956Z',
          },
        ]),
      );

      final ratings = await service.fetchMyRatings(1);

      expect(ratings.single.movieId, 13);
      expect(ratings.single.score, 3);
      expect(ratings.single.comment, isNull);
      expect(ratings.single.createdAt.isUtc, isTrue);
    });

    test('평점 조회 실패 문구는 상태 코드별로 다르다', () {
      expect(writeMyRatingsErrorMessage(_dioError(400)),
          'memberId 형식을 다시 확인해 주세요.');
      expect(writeMyRatingsErrorMessage(_dioError(404)), '존재하지 않는 회원입니다.');
      expect(writeMyRatingsErrorMessage(_dioError(null)),
          '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.');
    });

    test('TMDB 상세가 404면 findMovieById는 null을 돌려준다', () async {
      final service = TmdbMovieService(_dio(statusCode: 404));

      expect(await service.findMovieById(999999999), isNull);
    });
  });

  group('MyRatingsViewModel', () {
    test('평점마다 TMDB 영화를 붙이고, 같은 movieId는 한 번만 조회한다', () async {
      final movieService = _FakeTmdbMovieService();
      final viewModel = MyRatingsViewModel(
        _FakeRatingApiService([_rating(1, 550), _rating(2, 550), _rating(3, 13)]),
        movieService,
        sampleMemberId,
      );

      await viewModel.load();

      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.ratings.map((e) => e.movie?.title),
          ['영화 550', '영화 550', '영화 13']);
      expect(movieService.calls, [550, 13]);
      expect(viewModel.message, isNull);
    });

    test('빈 배열은 Error가 아니라 Empty', () async {
      final viewModel = MyRatingsViewModel(
        _FakeRatingApiService(const <RatingDto>[]),
        _FakeTmdbMovieService(),
        3,
      );

      await viewModel.load();

      expect(viewModel.status, MyRatingsLoadStatus.empty);
    });

    test('존재하지 않는 회원(404)은 Error와 안내 문구', () async {
      final viewModel = MyRatingsViewModel(
        _FakeRatingApiService(_dioError(404)),
        _FakeTmdbMovieService(),
        999999,
      );

      await viewModel.load();

      expect(viewModel.status, MyRatingsLoadStatus.error);
      expect(viewModel.message, '존재하지 않는 회원입니다.');
    });

    test('TMDB에서 영화를 못 찾거나 실패해도 평점은 남기고 안내 문구만 표시한다', () async {
      final movieService =
          _FakeTmdbMovieService(notFound: {13}, failing: {680});
      final viewModel = MyRatingsViewModel(
        _FakeRatingApiService([_rating(1, 13), _rating(2, 680), _rating(3, 550)]),
        movieService,
        sampleMemberId,
      );

      await viewModel.load();

      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.ratings, hasLength(3));
      expect(viewModel.ratings[0].movie, isNull);
      expect(viewModel.ratings[1].movie, isNull);
      expect(viewModel.message, contains('일부 영화 정보를 가져오지 못해'));

      // 404(null)는 캐시하고, 일시적인 네트워크 실패는 다음 로딩에서 다시 묻는다.
      await viewModel.load();
      expect(movieService.calls, [13, 680, 550, 680]);
    });
  });
}
