// 즐겨찾기 등록·목록 응답의 항목. 제목·포스터는 없어서 movieId로 TMDB에서 보충한다.
class FavoriteResponseDto {
  const FavoriteResponseDto({
    required this.favoriteId,
    required this.movieId,
    required this.createdAt,
  });

  factory FavoriteResponseDto.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('FavoriteResponseDto must be a JSON object.');
    }
    return FavoriteResponseDto(
      favoriteId: (json['favoriteId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int favoriteId;
  // TMDB 영화 id
  final int movieId;
  final DateTime createdAt;
}
