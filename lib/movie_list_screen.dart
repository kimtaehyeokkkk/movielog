import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/genre_chip_bar.dart';
import 'package:movielog/widgets/genre_filter_sheet.dart';
import 'package:movielog/widgets/movie_grid.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';
import 'package:movielog/widgets/movie_page_footer.dart';
import 'package:provider/provider.dart';

// 디버그 전용: 존재하지 않는 장르 id로 Discover를 요청해 실제 빈 응답(Empty)을 재현한다.
const _debugEmptyGenreId = 999999;

Future<void> _openGenreFilterSheet(BuildContext context) async {
  final viewModel = context.read<PagedMoviesViewModel>();
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
  // 확인하면 목록·page를 비우고 첫 page부터 다시 불러온다.
  if (selected == null || !context.mounted) return;
  await viewModel.selectGenres(selected);
}

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(
            tooltip: '영화 검색',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/movies/search'),
          ),
          if (kDebugMode)
            PopupMenuButton<void>(
              tooltip: '디버그',
              icon: const Icon(Icons.bug_report_outlined),
              itemBuilder: (menuContext) {
                final viewModel = context.read<PagedMoviesViewModel>();
                return [
                  PopupMenuItem(
                    onTap: viewModel.debugFailNextPage,
                    child: const Text('다음 페이지 요청 실패시키기'),
                  ),
                  PopupMenuItem(
                    onTap: () => viewModel.selectGenres([_debugEmptyGenreId]),
                    child: const Text('Empty 재현'),
                  ),
                ];
              },
            ),
        ],
      ),
      body: Consumer<PagedMoviesViewModel>(
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
                        onPressed: viewModel.isLoading
                            ? null
                            : () => _openGenreFilterSheet(context),
                      ),
                    ),
                    Expanded(
                      child: GenreChipBar(
                        genres: viewModel.genres,
                        selectedGenreIds: viewModel.selectedGenreIds,
                        enabled: !viewModel.isLoading,
                        onSelected: (genreId) => viewModel.selectGenres(
                          genreId == null ? null : [genreId],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Expanded(
                child: switch (viewModel.phase) {
                  LoadPhase.idle ||
                  LoadPhase.loading =>
                    const MovieListLoading(),
                  LoadPhase.error => MovieListError(
                      message: viewModel.errorMessage,
                      onRetry: viewModel.refresh,
                    ),
                  LoadPhase.empty => RefreshIndicator(
                      onRefresh: viewModel.refresh,
                      child: const MovieListEmpty(),
                    ),
                  LoadPhase.ready => RefreshIndicator(
                      onRefresh: viewModel.refresh,
                      child: _InfiniteMovieGrid(viewModel: viewModel),
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

// Challenge: 무한 스크롤. 끝에 가까워지면 다음 page를 자동으로 부른다.
// 다음 page가 실패하면 자동으로 다시 부르지 않고 footer의 다시 시도 버튼을 기다린다.
class _InfiniteMovieGrid extends StatefulWidget {
  const _InfiniteMovieGrid({required this.viewModel});

  final PagedMoviesViewModel viewModel;

  @override
  State<_InfiniteMovieGrid> createState() => _InfiniteMovieGridState();
}

class _InfiniteMovieGridState extends State<_InfiniteMovieGrid> {
  // 남은 스크롤 거리가 이보다 작으면 다음 page를 요청한다.
  static const _loadMoreThreshold = 400.0;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_maybeLoadMore);
  }

  void _maybeLoadMore() {
    final vm = widget.viewModel;
    if (!_controller.hasClients || vm.loadMoreError != null) return;
    // 중복 요청 방지(isLoadingMore·hasMore 확인)는 ViewModel이 한다.
    if (_controller.position.extentAfter < _loadMoreThreshold) {
      vm.loadNextPage();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_maybeLoadMore);
    _controller.dispose();
    super.dispose();
  }

  String _summary(PagedMoviesViewModel vm) {
    final selected = vm.selectedGenreIds;
    final count = '영화 ${vm.movies.length}편 · ${vm.loadedPage}/${vm.totalPages}페이지';
    if (selected == null) return count;
    final names = [for (final id in selected) vm.genreNames[id] ?? '$id'];
    return '$count · ${names.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // 첫 page만으로 화면이 다 차지 않으면 스크롤이 없으니 그려진 뒤 한 번 더 확인한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadMore();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _summary(vm),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        // 새로고침이 실패해도 기존 목록은 그대로 두고 안내만 한다.
        if (vm.refreshError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Text(
              vm.refreshError!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
        Expanded(
          child: MovieGrid(
            controller: _controller,
            movies: vm.movies,
            genreNames: vm.genreNames,
            footer: MoviePageFooter(vm: vm, autoLoad: true),
          ),
        ),
      ],
    );
  }
}
