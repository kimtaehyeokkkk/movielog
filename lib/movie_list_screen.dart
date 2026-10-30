import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/genre_chip_bar.dart';
import 'package:movielog/widgets/genre_filter_sheet.dart';
import 'package:movielog/widgets/load_retry_dialog.dart';
import 'package:movielog/widgets/movie_grid.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';
import 'package:provider/provider.dart';

// 디버그 전용: 존재하지 않는 장르 id로 Discover를 요청해 실제 빈 응답(Empty)을 재현한다.
const _debugEmptyGenreId = 999999;

// 최근 목록을 유지한 채 실패했으면 재시도 Dialog를 띄우고, 재시도할 때마다 다시 확인한다.
Future<void> _showRetryDialogIfNeeded(
  BuildContext context,
  MovieListLoadOutcome outcome,
) async {
  var current = outcome;

  while (current == MovieListLoadOutcome.failedWithPreviousList) {
    if (!context.mounted) return;
    final shouldRetry = await showDialog<bool>(
      context: context,
      builder: (context) => const LoadRetryDialog(),
    );
    if (shouldRetry != true || !context.mounted) return;
    current = await context.read<MovieListViewModel>().retry();
  }
}

Future<void> _selectGenres(BuildContext context, List<int>? genreIds) async {
  final outcome =
      await context.read<MovieListViewModel>().selectGenres(genreIds);
  if (!context.mounted) return;
  await _showRetryDialogIfNeeded(context, outcome);
}

Future<void> _openGenreFilterSheet(BuildContext context) async {
  final viewModel = context.read<MovieListViewModel>();
  final selected = await showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (context) => GenreFilterSheet(
      genres: viewModel.genres,
      initialSelected: {...?viewModel.selectedGenreIds},
    ),
  );

  // 시트를 그냥 닫으면 null → 선택을 바꾸지 않는다. 빈 목록이면 "전체".
  if (selected == null || !context.mounted) return;
  await _selectGenres(context, selected);
}

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
              onPressed: () => _selectGenres(context, [_debugEmptyGenreId]),
            ),
        ],
      ),
      body: Consumer<MovieListViewModel>(
        builder: (context, viewModel, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (viewModel.genres.isNotEmpty)
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: IconButton(
                        tooltip: '장르 여러 개 선택',
                        icon: const Icon(Icons.tune),
                        onPressed: viewModel.isBusy
                            ? null
                            : () => _openGenreFilterSheet(context),
                      ),
                    ),
                    Expanded(
                      child: GenreChipBar(
                        genres: viewModel.genres,
                        selectedGenreIds: viewModel.selectedGenreIds,
                        enabled: !viewModel.isBusy,
                        onSelected: (genreId) => _selectGenres(
                          context,
                          genreId == null ? null : [genreId],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Expanded(
                // Loading(Skeleton)은 RefreshIndicator 밖이라 당겨서 새로고침이 동작하지 않는다.
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
                  MovieListLoadStatus.empty => _RefreshableList(
                      child: const MovieListEmpty(),
                    ),
                  MovieListLoadStatus.success => _RefreshableList(
                      child: _MovieListContent(viewModel: viewModel),
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

class _RefreshableList extends StatelessWidget {
  const _RefreshableList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final outcome = await context.read<MovieListViewModel>().refresh();
        if (!context.mounted) return;
        // 인디케이터는 바로 닫고, Dialog는 그 뒤에 따로 띄운다.
        unawaited(_showRetryDialogIfNeeded(context, outcome));
      },
      child: child,
    );
  }
}

class _MovieListContent extends StatelessWidget {
  const _MovieListContent({required this.viewModel});

  final MovieListViewModel viewModel;

  String get _summary {
    final selected = viewModel.selectedGenreIds;
    final count = '영화 ${viewModel.movies.length}편';
    if (selected == null) return count;

    final names = [
      for (final id in selected) viewModel.genreNames[id] ?? '$id',
    ];
    return '$count · ${names.join(', ')}';
  }

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
            _summary,
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
