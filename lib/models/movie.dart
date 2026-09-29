class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genres,
    required this.year,
    required this.runtimeMinutes,
    required this.rating,
    required this.ratingCount,
    required this.posterAsset,
    required this.synopsis,
    required this.tags,
  });

  final int id;
  final String title;
  final List<String> genres;
  final int year;
  final int runtimeMinutes;
  final double rating;
  final int ratingCount;
  final String posterAsset;
  final String synopsis;
  final List<String> tags;

  String get primaryGenre => genres.first;
}