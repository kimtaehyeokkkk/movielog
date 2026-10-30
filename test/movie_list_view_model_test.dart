import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';

import 'support/fake_tmdb_movie_service.dart';

void main() {
  group('MovieListViewModel', () {
    test('페이지 사이 중복 id는 하나만 남기고 최대 30개에서 멈춘다', () async {
      final service = FakeTmdbMovieService([
        [for (var id = 1; id <= 20; id++) id],
        // 19, 20은 앞 페이지와 중복
        [for (var id = 19; id <= 38; id++) id],
        [for (var id = 39; id <= 58; id++) id],
      ]);
      final viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();

      expect(viewModel.movies.length, 30);
      expect(viewModel.movies.map((movie) => movie.id).toSet().length, 30);
      expect(service.requestedPages, [1, 2]);
      expect(viewModel.status, MovieListLoadStatus.success);
    });

    test('마지막 페이지에 도달하면 30개보다 적어도 그대로 성공한다', () async {
      final service = FakeTmdbMovieService([
        [1, 2, 3],
      ]);
      final viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();

      expect(viewModel.movies.length, 3);
      expect(service.requestedPages, [1]);
    });

    test('여러 장르를 선택하면 정렬된 id 목록으로 page 1부터 다시 요청한다', () async {
      final service = FakeTmdbMovieService([
        [1, 2],
      ]);
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      await viewModel.selectGenres([28, 12]);

      expect(service.requestedGenreIds.last, [12, 28]);
      expect(service.requestedPages.last, 1);
      expect(viewModel.selectedGenreIds, [12, 28]);
    });

    test('빈 선택은 "전체"(null)로 요청한다', () async {
      final service = FakeTmdbMovieService([
        [1],
      ]);
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();
      await viewModel.selectGenres([28]);

      await viewModel.selectGenres([]);

      expect(service.requestedGenreIds.last, isNull);
      expect(viewModel.selectedGenreIds, isNull);
    });

    test('최근 목록이 있으면 실패해도 목록과 장르를 유지하고 Dialog 결과를 돌려준다', () async {
      final service = FakeTmdbMovieService([
        [1, 2, 3],
      ]);
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      service.shouldFail = true;
      final outcome = await viewModel.selectGenres([28]);

      expect(outcome, MovieListLoadOutcome.failedWithPreviousList);
      expect(viewModel.movies.length, 3);
      expect(viewModel.selectedGenreIds, isNull);
      expect(viewModel.status, MovieListLoadStatus.success);

      // 재시도는 마지막으로 요청한 장르 조건(액션)으로 다시 요청한다.
      service.shouldFail = false;
      await viewModel.retry();

      expect(service.requestedGenreIds.last, [28]);
      expect(viewModel.selectedGenreIds, [28]);
    });

    test('최근 목록 없이 실패하면 Error 상태가 된다', () async {
      final service = FakeTmdbMovieService([
        [1],
      ])..shouldFail = true;
      final viewModel = MovieListViewModel(service);

      final outcome = await viewModel.loadInitial();

      expect(outcome, MovieListLoadOutcome.failed);
      expect(viewModel.status, MovieListLoadStatus.error);
    });

    test('새로고침 중에도 기존 목록을 비우지 않는다', () async {
      final service = FakeTmdbMovieService([
        [1, 2],
      ]);
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      final refreshing = viewModel.refresh();

      expect(viewModel.isRefreshing, isTrue);
      expect(viewModel.movies.length, 2);
      await refreshing;
      expect(viewModel.isRefreshing, isFalse);
    });
  });

  group('TmdbMovieService.discoverMovies', () {
    Future<RequestOptions> captureRequest(List<int>? genreIds) async {
      late RequestOptions captured;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              captured = options;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'page': 1,
                    'results': <dynamic>[],
                    'total_pages': 1,
                    'total_results': 0,
                  },
                ),
              );
            },
          ),
        );

      await TmdbMovieService(dio).discoverMovies(page: 1, genreIds: genreIds);
      return captured;
    }

    test('여러 장르 id는 | 로 연결해 with_genres로 보낸다', () async {
      final request = await captureRequest([28, 12]);

      expect(request.queryParameters['with_genres'], '28|12');
    });

    test('장르가 없으면 with_genres를 보내지 않는다', () async {
      final request = await captureRequest(null);

      expect(request.queryParameters.containsKey('with_genres'), isFalse);
    });
  });
}
