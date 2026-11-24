import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/utils/safe_notify.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_phase.dart';

typedef MovieQueryCondition = ({List<int>? genreIds, String query});

// 영화 목록(Discover)과 검색(Search)이 함께 쓰는 page 단위 목록. 화면마다 별도 인스턴스를 만든다.
// 5주차의 "최대 30개 한 번에 수집" 대신, 첫 page만 불러오고 다음 page는 요청할 때마다 하나씩 붙인다.
class PagedMoviesViewModel extends ChangeNotifier with SafeNotify {
  PagedMoviesViewModel({required this.tmdbApi});

  // TMDB page는 1~500이다. total_pages가 더 커도 501은 요청하지 않는다.
  static const maxTmdbPage = 500;

  final TmdbMovieService tmdbApi;

  LoadPhase phase = LoadPhase.idle;
  final List<TmdbMovieDto> movies = [];
  int nextPage = 1; // 다음에 요청할 page. 실패하면 그대로 둬서 같은 page를 다시 요청한다.
  int totalPages = 1; // min(서버 total_pages, 500)
  bool isLoadingMore = false;
  String? errorMessage; // 첫 조회 실패
  String? loadMoreError; // 다음 page 실패 (기존 목록은 지우지 않음)

  // 장르 목록 (영화 목록 화면에서만 사용)
  List<TmdbGenreDto> genres = const [];
  Map<int, String> genreNames = const {};

  // 조건이 바뀔 때마다 올라간다. 요청 시점 값과 다르면 이전 조건의 늦은 응답이라 버린다.
  int _requestGeneration = 0;
  MovieQueryCondition _condition = (genreIds: null, query: '');
  bool _debugFailNextPage = false;

  bool get hasMore => nextPage <= totalPages;
  List<int>? get selectedGenreIds => _condition.genreIds;
  String get query => _condition.query;
  bool get isLoading => phase == LoadPhase.loading;
  // 마지막으로 성공한 page (화면 요약용)
  int get loadedPage => nextPage - 1;

  // 새 조건(장르·검색어·새로고침)의 첫 page. 목록과 page·추가 로딩 상태를 모두 초기화한다.
  Future<void> loadInitial({List<int>? genreIds, String query = ''}) async {
    if (isDisposed) return;
    _condition = (genreIds: _normalize(genreIds), query: query.trim());
    final generation = ++_requestGeneration;
    phase = LoadPhase.loading;
    errorMessage = null;
    loadMoreError = null;
    isLoadingMore = false;
    movies.clear();
    nextPage = 1;
    totalPages = 1;
    notifyIfAlive();
    try {
      final page = await _fetchPage(1, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      _applyFirstPage(page);
    } catch (error) {
      if (generation != _requestGeneration || isDisposed) return;
      if (kDebugMode && error is! DioException) {
        debugPrint('[PagedMovies] 응답 변환 실패: $error');
      }
      phase = LoadPhase.error;
      errorMessage = _condition.query.isEmpty
          ? '영화 목록을 불러오지 못했습니다.'
          : '검색 결과를 불러오지 못했습니다.';
    } finally {
      if (generation == _requestGeneration && !isDisposed) notifyIfAlive();
    }
  }

  // 현재 조건 그대로 첫 page부터 다시 (당겨서 새로고침·오류 화면의 다시 시도)
  Future<void> refresh() =>
      loadInitial(genreIds: _condition.genreIds, query: _condition.query);

  // 장르 변경: 같은 조건이면 다시 요청하지 않는다. (오류 상태면 다시 시도)
  Future<void> selectGenres(List<int>? genreIds) async {
    final normalized = _normalize(genreIds);
    if (listEquals(normalized, _condition.genreIds) &&
        phase != LoadPhase.error) {
      return;
    }
    await loadInitial(genreIds: normalized);
  }

  // 다음 page. 실패해도 nextPage를 올리지 않아 같은 page를 다시 요청할 수 있다.
  Future<void> loadNextPage() async {
    if (isDisposed || isLoadingMore || !hasMore || phase != LoadPhase.ready) {
      return;
    }
    final generation = _requestGeneration;
    final pageToLoad = nextPage;
    isLoadingMore = true;
    loadMoreError = null;
    notifyIfAlive();
    try {
      if (_debugFailNextPage) {
        _debugFailNextPage = false;
        throw DioException(
          requestOptions: RequestOptions(path: '/page/$pageToLoad'),
          type: DioExceptionType.connectionError,
          message: 'debug: 다음 page 실패 재현',
        );
      }
      final page = await _fetchPage(pageToLoad, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      _appendPage(page);
    } catch (_) {
      if (generation != _requestGeneration || isDisposed) return;
      loadMoreError = '$pageToLoad페이지를 불러오지 못했습니다. 같은 페이지를 다시 요청합니다.';
    } finally {
      if (generation == _requestGeneration && !isDisposed) {
        isLoadingMore = false;
        notifyIfAlive();
      }
    }
  }

  // 장르 목록은 한 번만 받는다. 실패해도 영화 목록은 보여주고 장르 칩만 숨긴다.
  Future<void> loadGenres() async {
    if (genres.isNotEmpty || isDisposed) return;
    try {
      final fetched = await tmdbApi.fetchGenres();
      if (isDisposed) return;
      genres = fetched;
      genreNames = {for (final genre in fetched) genre.id: genre.name};
      notifyIfAlive();
    } catch (_) {
      // 장르 칩 없이 진행
    }
  }

  // kDebugMode 전용: 다음 page 요청 한 번을 실패시켜 같은 page 재시도를 재현한다.
  void debugFailNextPage() => _debugFailNextPage = true;

  Future<TmdbMoviePageDto> _fetchPage(
    int page,
    MovieQueryCondition condition,
  ) async {
    final result = condition.query.isNotEmpty
        ? await tmdbApi.searchMovies(page: page, query: condition.query)
        : await tmdbApi.discoverMovies(page: page, genreIds: condition.genreIds);
    if (result.page != page || result.page < 1 || result.totalPages < 0) {
      throw const FormatException('TMDB page metadata is inconsistent.');
    }
    return result;
  }

  void _applyFirstPage(TmdbMoviePageDto page) {
    movies
      ..clear()
      ..addAll(_dedupe(page.results));
    totalPages = page.totalPages > maxTmdbPage ? maxTmdbPage : page.totalPages;
    nextPage = page.page + 1;
    phase = movies.isEmpty ? LoadPhase.empty : LoadPhase.ready;
  }

  // TMDB는 page가 바뀌어도 같은 영화를 다시 줄 수 있어 이미 가진 movieId는 뺀다.
  void _appendPage(TmdbMoviePageDto page) {
    movies.addAll(_dedupe(page.results));
    totalPages = page.totalPages > maxTmdbPage ? maxTmdbPage : page.totalPages;
    nextPage = page.page + 1;
  }

  List<TmdbMovieDto> _dedupe(List<TmdbMovieDto> incoming) {
    final seen = movies.map((movie) => movie.id).toSet();
    return incoming.where((movie) => seen.add(movie.id)).toList(growable: false);
  }

  // 빈 선택은 "전체"(null), 순서는 정렬해 같은 조건을 같은 값으로 비교한다.
  List<int>? _normalize(List<int>? genreIds) {
    if (genreIds == null || genreIds.isEmpty) return null;
    return [...genreIds.toSet()]..sort();
  }
}
