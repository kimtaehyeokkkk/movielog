import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';

import 'support/fake_auth.dart';

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

// movieId별로 영화·null(404)·네트워크 실패·응답 변환 실패를 돌려주는 TMDB Service.
// 동시에 진행 중인 조회 수의 최댓값도 기록한다.
class _FakeTmdbMovieService extends TmdbMovieService {
  _FakeTmdbMovieService({
    this.notFound = const {},
    this.failing = const {},
    this.malformed = const {},
  }) : super(Dio());

  final Set<int> notFound;
  final Set<int> failing;
  final Set<int> malformed;
  final calls = <int>[];
  int _inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async {
    calls.add(movieId);
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      await Future<void>.delayed(Duration.zero);
      if (failing.contains(movieId)) throw networkError();
      if (notFound.contains(movieId)) return null;
      // id가 빠진 응답 → fromJson에서 TypeError
      if (malformed.contains(movieId)) {
        return TmdbMovieDto.fromJson({'title': '깨진 응답'});
      }
      return _movie(movieId);
    } finally {
      _inFlight--;
    }
  }
}

// TMDB 404를 돌려주는 Dio
Dio _notFoundDio() {
  return Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 404),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );
}

// 이번 세션에서 등록한 평점(SessionRatings)을 TMDB 영화와 묶는 ViewModel을 만든다.
Future<MyRatingsViewModel> _viewModel(
  List<RatingDto> ratings,
  TmdbMovieService movieService,
) async {
  final auth = await signedInAuth();
  final sessionRatings = SessionRatings(auth);
  for (final rating in ratings.reversed) {
    sessionRatings.add(rating, sessionVersion: auth.sessionVersion);
  }
  return MyRatingsViewModel(
    RatingApiService(Dio(), Dio()),
    movieService,
    sessionRatings,
    auth,
  );
}

void main() {
  test('TMDB 상세가 404면 findMovieById는 null을 돌려준다', () async {
    final service = TmdbMovieService(_notFoundDio());

    expect(await service.findMovieById(999999999), isNull);
  });

  group('MyRatingsViewModel (movieId → TMDB 영화 결합)', () {
    test('평점마다 TMDB 영화를 붙이고, 같은 movieId는 한 번만 조회한다', () async {
      final movieService = _FakeTmdbMovieService();
      final viewModel = await _viewModel(
        [ratingDto(1, 550), ratingDto(2, 550), ratingDto(3, 13)],
        movieService,
      );

      await viewModel.load();

      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.ratings.map((e) => e.movie?.title),
          ['영화 550', '영화 550', '영화 13']);
      expect(movieService.calls, [550, 13]);
      expect(viewModel.message, isNull);
    });

    test('이번 세션에 등록한 평점이 없으면 Empty', () async {
      final viewModel = await _viewModel(const [], _FakeTmdbMovieService());

      await viewModel.load();

      expect(viewModel.status, MyRatingsLoadStatus.empty);
    });

    test('TMDB에서 영화를 못 찾거나 실패해도 평점은 남기고 안내 문구만 표시한다', () async {
      final movieService =
          _FakeTmdbMovieService(notFound: {13}, failing: {680});
      final viewModel = await _viewModel(
        [ratingDto(1, 13), ratingDto(2, 680), ratingDto(3, 550)],
        movieService,
      );

      await viewModel.load();

      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.ratings, hasLength(3));
      expect(viewModel.ratings[0].movie, isNull);
      expect(viewModel.ratings[1].movie, isNull);
      expect(viewModel.message, contains('영화 ID로 대신 표시'));

      // 404(null)는 캐시하고, 일시적인 네트워크 실패는 다음 로딩에서 다시 묻는다.
      await viewModel.load();
      expect(movieService.calls, [13, 680, 550, 680]);
    });

    test('영화 응답 변환에 실패해도 그 영화만 null로 둔다', () async {
      final viewModel = await _viewModel(
        [ratingDto(1, 13), ratingDto(2, 550)],
        _FakeTmdbMovieService(malformed: {13}),
      );

      await viewModel.load();

      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.ratings[0].movie, isNull);
      expect(viewModel.ratings[1].movie?.title, '영화 550');
    });

    test('영화 정보는 차례로가 아니라 최대 5개씩 동시에 조회한다', () async {
      final movieService = _FakeTmdbMovieService();
      final viewModel = await _viewModel(
        [for (var id = 1; id <= 7; id++) ratingDto(id, 100 + id)],
        movieService,
      );

      await viewModel.load();

      expect(movieService.calls, hasLength(7));
      expect(movieService.maxInFlight, 5);
      expect(viewModel.ratings.map((e) => e.movie?.id),
          [for (var id = 1; id <= 7; id++) 100 + id]);
    });
  });
}
