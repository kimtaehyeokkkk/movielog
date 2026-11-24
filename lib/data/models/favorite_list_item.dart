import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';

// 내 즐겨찾기 카드 한 장: MovieLog 즐겨찾기 + movieId로 찾은 TMDB 영화 정보.
// TMDB 조회에 실패하면 movie는 null이고, 그 카드만 placeholder와 재조회 버튼을 보여준다.
class FavoriteListItem {
  const FavoriteListItem({
    required this.favorite,
    this.movie,
    this.errorMessage,
  });

  final FavoriteResponseDto favorite;
  final TmdbMovieDto? movie;
  final String? errorMessage;

  bool get hasMovie => movie != null;
}
