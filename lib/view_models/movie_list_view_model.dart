import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service);

  static const maxMovies = 30;

  final TmdbMovieService _service;

  List<TmdbMovieDto> movies = const [];
  List<TmdbGenreDto> genres = const [];
  Map<int, String> genreNames = const {};
  int? selectedGenreId;
  MovieListLoadStatus status = MovieListLoadStatus.idle;
  String? message;
  bool isTimeout = false;

  int _requestVersion = 0;
  bool _disposed = false;

  bool get isLoading => status == MovieListLoadStatus.loading;

  Future<void> loadInitial() => _loadMovies();

  // 재시도는 마지막으로 선택한 장르 조건 그대로 page 1부터 다시 요청한다.
  Future<void> retry() => _loadMovies();

  Future<void> selectGenre(int? genreId) async {
    // 요청 중에는 장르를 바꾸지 않는다. ("전체"는 genreId == null)
    if (isLoading || genreId == selectedGenreId) return;
    selectedGenreId = genreId;
    await _loadMovies();
  }

  Future<void> _loadMovies() async {
    final version = ++_requestVersion;
    status = MovieListLoadStatus.loading;
    message = null;
    isTimeout = false;
    notifyListeners();

    try {
      // 장르 목록은 한 번 받아 두고, 아직 없을 때(첫 로드·이전 실패)만 요청한다.
      if (genres.isEmpty) {
        final fetchedGenres = await _service.fetchGenres();
        if (_isStale(version)) return;
        genres = fetchedGenres;
        genreNames = {for (final genre in fetchedGenres) genre.id: genre.name};
      }

      final result = await _fetchUpToThirtyMovies(
        version: version,
        genreId: selectedGenreId,
      );
      if (_isStale(version)) return;

      movies = result;
      status = result.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
    } on DioException catch (error) {
      if (_isStale(version)) return;
      status = MovieListLoadStatus.error;
      isTimeout = error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout;
      message = '영화를 불러오지 못했어요.';
    } catch (error) {
      // 응답 JSON 모양이 달라 DTO 변환에 실패해도 Loading에 멈추지 않게 한다.
      if (_isStale(version)) return;
      if (kDebugMode) debugPrint('[MovieList] 응답 변환 실패: $error');
      status = MovieListLoadStatus.error;
      message = '영화 정보를 읽지 못했어요.';
    }

    notifyListeners();
  }

  // 결과가 30개가 되거나 더 이상 페이지가 없을 때까지 page 1부터 요청한다.
  Future<List<TmdbMovieDto>> _fetchUpToThirtyMovies({
    required int version,
    int? genreId,
  }) async {
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < maxMovies && hasNextPage) {
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreId: genreId,
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

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
