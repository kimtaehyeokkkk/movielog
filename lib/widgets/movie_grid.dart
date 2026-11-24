import 'package:flutter/material.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/widgets/movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({
    super.key,
    required this.movies,
    this.genreNames = const {},
    this.footer,
    this.controller,
  });

  final List<TmdbMovieDto> movies;
  // Genre API로 받은 id → 이름. 카드에는 첫 번째 장르만 표시한다.
  final Map<int, String> genreNames;
  // 카드 목록 아래에 붙는 위젯 (더 보기·재시도·끝)
  final Widget? footer;
  // 무한 스크롤에서 남은 스크롤 거리를 확인할 때 쓴다.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverGrid.builder(
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
          ),
        ),
        if (footer != null) SliverToBoxAdapter(child: footer),
      ],
    );
  }
}
