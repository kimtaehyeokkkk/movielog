import 'package:flutter/material.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/widgets/movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({
    super.key,
    required this.movies,
    this.genreNames = const {},
  });

  final List<TmdbMovieDto> movies;
  // Genre API로 받은 id → 이름. 카드에는 첫 번째 장르만 표시한다.
  final Map<int, String> genreNames;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: movies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.55,
      ),
      itemBuilder: (context, index) {
        final movie = movies[index];
        final genreIds = movie.genreIds;

        return MovieCard(
          movie: movie,
          genreName: genreIds.isEmpty ? null : genreNames[genreIds.first],
        );
      },
    );
  }
}
