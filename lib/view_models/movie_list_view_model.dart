import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

// 요청 결과. View는 failedWithPreviousList일 때만 재시도 Dialog를 띄운다.
enum MovieListLoadOutcome { success, failed, failedWithPreviousList, ignored }

class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service);

  static const maxMovies = 30;

  final TmdbMovieService _service;

  List<TmdbMovieDto> movies = const [];
  List<TmdbGenreDto> genres = const [];
  Map<int, String> genreNames = const {};
  // null이면 "전체". 화면에 보이는 목록의 장르 조건이다.
  List<int>? selectedGenreIds;
  MovieListLoadStatus status = MovieListLoadStatus.idle;
  String? message;
  bool isTimeout = false;
  bool isRefreshing = false;

  // 마지막으로 요청한 장르 조건. 실패 후 재시도는 이 조건으로 다시 요청한다.
  List<int>? _requestedGenreIds;
  // 최근 성공한 목록과 그때의 장르 조건. 실패해도 이 목록으로 되돌린다.
  List<TmdbMovieDto>? _lastSuccessMovies;
  List<int>? _lastSuccessGenreIds;

  int _requestVersion = 0;
  bool _disposed = false;

  bool get isLoading => status == MovieListLoadStatus.loading;

  // 요청 중에는 장르 변경·새로고침을 막는다.
  bool get isBusy => isLoading || isRefreshing;

  Future<MovieListLoadOutcome> loadInitial() => _load(selectedGenreIds);

  Future<MovieListLoadOutcome> retry() => _load(_requestedGenreIds);

  Future<MovieListLoadOutcome> selectGenre(int? genreId) {
    return selectGenres(genreId == null ? null : [genreId]);
  }

  Future<MovieListLoadOutcome> selectGenres(List<int>? genreIds) async {
    final normalized = _normalize(genreIds);
    if (isBusy || listEquals(normalized, selectedGenreIds)) {
      return MovieListLoadOutcome.ignored;
    }
    return _load(normalized);
  }

  // 새로고침은 현재 장르 조건을 유지하고, 완료될 때까지 기존 목록을 그대로 보여준다.
  Future<MovieListLoadOutcome> refresh() async {
    if (isBusy) return MovieListLoadOutcome.ignored;
    return _load(selectedGenreIds, refreshing: true);
  }

  Future<MovieListLoadOutcome> _load(
    List<int>? genreIds, {
    bool refreshing = false,
  }) async {
    final version = ++_requestVersion;
    _requestedGenreIds = genreIds;
    selectedGenreIds = genreIds;
    message = null;
    isTimeout = false;
    if (refreshing) {
      isRefreshing = true;
    } else {
      // 장르 조건이 바뀌면 목록을 비우고 page 1부터 다시 불러온다.
      movies = const [];
      status = MovieListLoadStatus.loading;
    }
    notifyListeners();

    MovieListLoadOutcome outcome;
    try {
      // 장르 목록은 한 번 받아 두고, 아직 없을 때(첫 로드·이전 실패)만 요청한다.
      if (genres.isEmpty) {
        final fetchedGenres = await _service.fetchGenres();
        if (_isStale(version)) return MovieListLoadOutcome.ignored;
        genres = fetchedGenres;
        genreNames = {for (final genre in fetchedGenres) genre.id: genre.name};
      }

      final result = await _fetchUpToThirtyMovies(
        version: version,
        genreIds: genreIds,
      );
      if (_isStale(version)) return MovieListLoadOutcome.ignored;

      movies = result;
      status = result.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
      _lastSuccessMovies = result;
      _lastSuccessGenreIds = genreIds;
      outcome = MovieListLoadOutcome.success;
    } on DioException catch (error) {
      if (_isStale(version)) return MovieListLoadOutcome.ignored;
      outcome = _fail(
        message: '영화를 불러오지 못했어요.',
        isTimeout: error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout,
      );
    } catch (error) {
      // 응답 JSON 모양이 달라 DTO 변환에 실패해도 Loading에 멈추지 않게 한다.
      if (_isStale(version)) return MovieListLoadOutcome.ignored;
      if (kDebugMode) debugPrint('[MovieList] 응답 변환 실패: $error');
      outcome = _fail(message: '영화 정보를 읽지 못했어요.');
    }

    isRefreshing = false;
    notifyListeners();
    return outcome;
  }

  MovieListLoadOutcome _fail({required String message, bool isTimeout = false}) {
    final previous = _lastSuccessMovies;

    // 최근 성공한 목록이 있으면 그 목록과 장르 조건으로 되돌리고, 재시도는 Dialog에 맡긴다.
    if (previous != null) {
      movies = previous;
      selectedGenreIds = _lastSuccessGenreIds;
      status = previous.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
      return MovieListLoadOutcome.failedWithPreviousList;
    }

    status = MovieListLoadStatus.error;
    this.message = message;
    this.isTimeout = isTimeout;
    return MovieListLoadOutcome.failed;
  }

  // 결과가 30개가 되거나 더 이상 페이지가 없을 때까지 page 1부터 요청한다.
  Future<List<TmdbMovieDto>> _fetchUpToThirtyMovies({
    required int version,
    List<int>? genreIds,
  }) async {
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < maxMovies && hasNextPage) {
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreIds: genreIds,
      );
      // 장르가 바뀌어 새 요청이 시작됐으면 남은 페이지는 요청하지 않는다.
      if (_isStale(version)) break;

      // TMDB id를 key로 써서 페이지 사이 중복은 하나만 남긴다.
      for (final movie in page.results) {
        byId[movie.id] = movie;
        if (byId.length == maxMovies) break;
      }

      hasNextPage = pageNumber < page.totalPages && page.results.isNotEmpty;
      pageNumber++;
    }

    return byId.values.take(maxMovies).toList();
  }

  // 빈 선택은 "전체"(null)로, 순서는 정렬해 같은 조건을 같은 값으로 비교한다.
  List<int>? _normalize(List<int>? genreIds) {
    if (genreIds == null || genreIds.isEmpty) return null;
    return [...genreIds.toSet()]..sort();
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
