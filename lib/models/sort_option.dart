import 'package:movielog/models/movie.dart';

enum SortOption {
  rating('평점순'),
  latest('최신순'),
  title('제목순');

  const SortOption(this.label);

  final String label;

  static SortOption fromName(String? name) {
    for (final option in SortOption.values) {
      if (option.name == name) return option;
    }
    return SortOption.rating;
  }

  List<Movie> sort(List<Movie> source) {
    final sorted = [...source];
    sorted.sort((a, b) {
      final primary = switch (this) {
        SortOption.rating => b.rating.compareTo(a.rating),
        SortOption.latest => b.year.compareTo(a.year),
        SortOption.title => a.title.compareTo(b.title),
      };
      if (primary != 0) return primary;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }
}