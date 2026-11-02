import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';

// 자체 백엔드의 평점과 그 movieId로 찾은 TMDB 영화 정보를 한 쌍으로 묶는다.
class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final RatingDto rating;
  // TMDB에서 찾지 못했으면 null. 평점은 그대로 보여주고 제목·포스터만 대신 표시한다.
  final TmdbMovieDto? movie;
}
