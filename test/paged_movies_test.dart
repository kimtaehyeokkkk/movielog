import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

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

// page 번호 → 영화 id 목록으로 응답하는 TMDB. 실패·지연을 page별로 주입할 수 있다.
class _PagedTmdb extends TmdbMovieService {
  _PagedTmdb(this.pages, {this.totalPages}) : super(Dio());

  final Map<int, List<int>> pages;
  final int? totalPages;
  final Set<int> failingPages = {};
  final Map<String, Completer<void>> delays = {};
  final requests = <String>[];

  TmdbMoviePageDto _page(int page, String key) {
    if (failingPages.remove(page)) throw networkError();
    return TmdbMoviePageDto(
      page: page,
      results: [for (final id in pages[page] ?? const <int>[]) _movie(id)],
      totalPages: totalPages ?? pages.length,
      totalResults: 0,
    );
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
  }) async {
    final key = 'discover:${genreIds ?? 'all'}:$page';
    requests.add(key);
    await delays[key]?.future;
    return _page(page, key);
  }

  @override
  Future<TmdbMoviePageDto> searchMovies({
    required int page,
    required String query,
  }) async {
    final key = 'search:$query:$page';
    requests.add(key);
    await delays[key]?.future;
    return _page(page, key);
  }
}

void main() {
  test('첫 page만 불러오고, 다음 page는 중복 movieId를 빼고 이어 붙인다', () async {
    final tmdb = _PagedTmdb({
      1: [1, 2, 3],
      2: [3, 4, 5], // 3은 page 1과 중복
    });
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);

    await vm.loadInitial();
    expect(vm.phase, LoadPhase.ready);
    expect(vm.movies.map((m) => m.id), [1, 2, 3]);
    expect(tmdb.requests, ['discover:all:1']);

    await vm.loadNextPage();
    expect(vm.movies.map((m) => m.id), [1, 2, 3, 4, 5]);
    expect(vm.nextPage, 3);
    expect(vm.hasMore, isFalse);
  });

  test('다음 page가 실패하면 목록과 nextPage를 유지하고 같은 page를 다시 요청한다', () async {
    final tmdb = _PagedTmdb({1: [1], 2: [2], 3: [3]});
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);
    await vm.loadInitial();
    tmdb.failingPages.add(2);

    await vm.loadNextPage();
    expect(vm.loadMoreError, contains('2페이지'));
    expect(vm.movies.map((m) => m.id), [1]);
    expect(vm.nextPage, 2);
    expect(vm.isLoadingMore, isFalse);

    await vm.loadNextPage();
    expect(vm.loadMoreError, isNull);
    expect(vm.movies.map((m) => m.id), [1, 2]);
    expect(tmdb.requests.where((r) => r.endsWith(':2')), hasLength(2));
  });

  test('debug 메뉴로 다음 page 한 번만 실패시킬 수 있다', () async {
    final vm = PagedMoviesViewModel(tmdbApi: _PagedTmdb({1: [1], 2: [2]}));
    await vm.loadInitial();

    vm.debugFailNextPage();
    await vm.loadNextPage();
    expect(vm.loadMoreError, isNotNull);

    await vm.loadNextPage();
    expect(vm.movies.map((m) => m.id), [1, 2]);
  });

  test('total_pages가 500보다 커도 501은 요청하지 않는다', () async {
    final vm = PagedMoviesViewModel(
      tmdbApi: _PagedTmdb({1: [1]}, totalPages: 9000),
    );

    await vm.loadInitial();

    expect(vm.totalPages, 500);
  });

  test('장르를 바꾸면 이전 장르의 늦은 첫 page 응답은 버린다', () async {
    final tmdb = _PagedTmdb({1: [1, 2]});
    tmdb.delays['discover:all:1'] = Completer();
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);

    final slow = vm.loadInitial();
    await vm.selectGenres([28]);
    tmdb.delays['discover:all:1']!.complete();
    await slow;

    expect(vm.selectedGenreIds, [28]);
    expect(tmdb.requests.last, 'discover:[28]:1');
    expect(vm.phase, LoadPhase.ready);
  });

  test('조건이 바뀌면 진행 중이던 다음 page 응답·로딩 표시가 남지 않는다', () async {
    final tmdb = _PagedTmdb({1: [1], 2: [2]});
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);
    await vm.loadInitial();
    tmdb.delays['discover:all:2'] = Completer();

    final slowNext = vm.loadNextPage();
    expect(vm.isLoadingMore, isTrue);
    await vm.selectGenres([18]);
    tmdb.delays['discover:all:2']!.complete();
    await slowNext;

    expect(vm.isLoadingMore, isFalse);
    expect(vm.movies.map((m) => m.id), [1]); // 장르 18의 첫 page만
    expect(vm.nextPage, 2);
  });

  test('검색은 Search API로, 검색어를 바꾸면 이전 검색어의 늦은 응답을 버린다', () async {
    final tmdb = _PagedTmdb({1: [7]});
    tmdb.delays['search:어벤:1'] = Completer();
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);

    final slow = vm.loadInitial(query: '어벤');
    await vm.loadInitial(query: ' 어벤져스 ');
    tmdb.delays['search:어벤:1']!.complete();
    await slow;

    expect(vm.query, '어벤져스');
    expect(tmdb.requests, ['search:어벤:1', 'search:어벤져스:1']);
    expect(vm.movies.map((m) => m.id), [7]);
  });

  test('결과가 없으면 empty, 첫 조회 실패는 error', () async {
    final emptyVm = PagedMoviesViewModel(tmdbApi: _PagedTmdb({1: []}));
    await emptyVm.loadInitial(query: '없는영화');
    expect(emptyVm.phase, LoadPhase.empty);

    final tmdb = _PagedTmdb({1: [1]})..failingPages.add(1);
    final errorVm = PagedMoviesViewModel(tmdbApi: tmdb);
    await errorVm.loadInitial(query: '영화');
    expect(errorVm.phase, LoadPhase.error);
    expect(errorVm.errorMessage, '검색 결과를 불러오지 못했습니다.');

    await errorVm.refresh();
    expect(errorVm.phase, LoadPhase.ready);
  });

  test('화면이 사라진 뒤 도착한 응답은 반영하지 않는다', () async {
    final tmdb = _PagedTmdb({1: [1]});
    tmdb.delays['discover:all:1'] = Completer();
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);

    final loading = vm.loadInitial();
    vm.dispose();
    tmdb.delays['discover:all:1']!.complete();
    await loading;

    expect(vm.isDisposed, isTrue);
    expect(vm.movies, isEmpty);
  });
}
