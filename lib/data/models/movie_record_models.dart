import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/rating_dto.dart';

// Challenge: POST /v8/movie-records 요청 body. 평점과 즐겨찾기를 한 트랜잭션으로 저장한다.
class CreateMovieRecordRequest {
  const CreateMovieRecordRequest({
    required this.movieId,
    required this.score,
    this.comment,
    required this.addToFavorites,
  });

  final int movieId; // TMDB 영화 id
  final int score; // 1~5 정수
  final String? comment;
  final bool addToFavorites; // 필수

  Map<String, dynamic> toJson() => {
        'movieId': movieId,
        'score': score,
        if (comment != null && comment!.trim().isNotEmpty)
          'comment': comment!.trim(),
        'addToFavorites': addToFavorites,
      };
}

// 201 result. addToFavorites가 false면 favorite은 null이 정상이다.
class MovieRecordResult {
  const MovieRecordResult({required this.rating, this.favorite});

  factory MovieRecordResult.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('MovieRecordResult must be a JSON object.');
    }
    final favorite = json['favorite'];
    return MovieRecordResult(
      rating: RatingDto.fromJson(json['rating'] as Map<String, dynamic>),
      favorite: favorite == null ? null : FavoriteResponseDto.fromJson(favorite),
    );
  }

  final RatingDto rating;
  final FavoriteResponseDto? favorite;
}
