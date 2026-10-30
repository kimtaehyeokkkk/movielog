import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/genre_chip_bar.dart';
import 'package:movielog/widgets/movie_grid.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';
import 'package:provider/provider.dart';

// 디버그 전용: 존재하지 않는 장르 id로 Discover를 요청해 실제 빈 응답(Empty)을 재현한다.
const _debugEmptyGenreId = 999999;

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: '디버그: Empty 재현',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () => context
                  .read<MovieListViewModel>()
                  .selectGenre(_debugEmptyGenreId),
            ),
        ],
      ),
      body: Consumer<MovieListViewModel>(
        builder: (context, viewModel, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (viewModel.genres.isNotEmpty)
                GenreChipBar(
                  genres: viewModel.genres,
                  selectedGenreId: viewModel.selectedGenreId,
                  enabled: !viewModel.isLoading,
                  onSelected: (genreId) => context
                      .read<MovieListViewModel>()
                      .selectGenre(genreId),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: switch (viewModel.status) {
                  MovieListLoadStatus.idle ||
                  MovieListLoadStatus.loading =>
                    const MovieListLoading(),
                  MovieListLoadStatus.error => MovieListError(
                      message: viewModel.message,
                      isTimeout: viewModel.isTimeout,
                      onRetry: () =>
                          context.read<MovieListViewModel>().retry(),
                    ),
                  MovieListLoadStatus.empty => const MovieListEmpty(),
                  MovieListLoadStatus.success => _MovieListContent(
                      viewModel: viewModel,
                    ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MovieListContent extends StatelessWidget {
  const _MovieListContent({required this.viewModel});

  final MovieListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '영화 ${viewModel.movies.length}편',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: MovieGrid(
            movies: viewModel.movies,
            genreNames: viewModel.genreNames,
          ),
        ),
      ],
    );
  }
}
