import 'package:dio/dio.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

TmdbMovieDto fakeMovie(int id) {
  return TmdbMovieDto(
    id: id,
    title: '영화 $id',
    overview: '',
    posterPath: null,
    backdropPath: null,
    releaseDate: null,
    genreIds: const [28],
    voteAverage: 7,
    popularity: 1,
  );
}

// 실제 HTTP 없이 페이지 응답을 돌려주는 Service. 요청 기록과 실패 주입을 지원한다.
class FakeTmdbMovieService extends TmdbMovieService {
  FakeTmdbMovieService(this.pages) : super(Dio());

  final List<List<int>> pages;
  final requestedGenreIds = <List<int>?>[];
  final requestedPages = <int>[];
  bool shouldFail = false;
  // 0보다 크면 실제 네트워크처럼 응답을 늦춰, 그 사이 Loading 화면이 그려지게 한다.
  Duration delay = Duration.zero;

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    return const [
      TmdbGenreDto(id: 28, name: '액션'),
      TmdbGenreDto(id: 12, name: '모험'),
    ];
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
  }) async {
    requestedPages.add(page);
    requestedGenreIds.add(genreIds);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (shouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/discover/movie'),
        type: DioExceptionType.connectionError,
      );
    }
    return TmdbMoviePageDto(
      page: page,
      results: [for (final id in pages[page - 1]) fakeMovie(id)],
      totalPages: pages.length,
      totalResults: pages.fold(0, (sum, ids) => sum + ids.length),
    );
  }
}
