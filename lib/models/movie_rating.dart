// 평점 Dialog의 결과. movieId는 배열 index가 아닌 TMDB 영화 id이며,
// 이후 자체 API의 CreateRatingRequest.movieId로 그대로 전달한다.
class MovieRating {
  const MovieRating({required this.movieId, required this.score});

  final int movieId;
  final double score;
}
