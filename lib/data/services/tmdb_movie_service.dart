import 'package:dio/dio.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';

// HTTP 요청과 DTO 변환만 담당한다. 개수 제한·장르 선택 같은 화면 정책은 ViewModel 책임.
class TmdbMovieService {
  TmdbMovieService(this._dio);

  final Dio _dio;

  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    final response = await _dio.get(
      '/movie/popular',
      queryParameters: {'language': 'ko-KR', 'page': page},
    );
    return TmdbMoviePageDto.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
  }) async {
    // 여러 장르는 OR 조건(|)으로 연결한다. 없으면("전체") null.
    final withGenres =
        genreIds == null || genreIds.isEmpty ? null : genreIds.join('|');

    final response = await _dio.get(
      '/discover/movie',
      queryParameters: {
        'language': 'ko-KR',
        'page': page,
        'sort_by': 'popularity.desc',
        'include_adult': false,
        'include_video': false,
        // "전체"면 with_genres 키 자체를 보내지 않는다.
        'with_genres': ?withGenres,
      },
    );
    return TmdbMoviePageDto.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<List<TmdbGenreDto>> fetchGenres() async {
    final response = await _dio.get(
      '/genre/movie/list',
      queryParameters: {'language': 'ko'},
    );
    final data = response.data as Map<String, dynamic>;
    final genres = data['genres'] as List<dynamic>? ?? const [];
    return genres
        .map((item) => TmdbGenreDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
