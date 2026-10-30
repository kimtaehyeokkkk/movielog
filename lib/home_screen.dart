import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/home_hero_banner.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/ranked_movie_card.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: 'MovieLog'),
      // AppBar는 상태와 무관하므로 Consumer로 body만 다시 그린다.
      body: Consumer<MovieHomeViewModel>(
        builder: (context, viewModel, child) {
          return switch (viewModel.status) {
            MovieHomeLoadStatus.idle ||
            MovieHomeLoadStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            MovieHomeLoadStatus.error => MovieListError(
                onRetry: () => context.read<MovieHomeViewModel>().loadPopular(),
              ),
            MovieHomeLoadStatus.empty =>
              const MovieListEmpty(message: '인기 영화가 없습니다.'),
            MovieHomeLoadStatus.success =>
              _HomeContent(popular: viewModel.popularMovies),
          };
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.popular});

  final List<TmdbMovieDto> popular;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '오늘은 어떤\n영화를 볼까요?',
              style: textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HomeHeroBanner(movie: popular.first),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text('인기 영화', style: textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () => context.go('/movies'),
                  child: const Text('전체보기 >'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: popular.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return RankedMovieCard(
                  movie: popular[index],
                  rank: index + 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
