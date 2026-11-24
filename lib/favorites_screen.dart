import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/favorite_list_item.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

// 마이페이지 → 내 즐겨찾기. root Navigator 위에 올라와 하단 탭이 보이지 않는다.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.onOpenMovie});

  // 상세로 이동했다가 돌아올 때까지 기다리는 함수. 돌아오면 목록을 다시 조회한다.
  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesViewModel>().refresh();
    });
  }

  // 상세에서 해제하고 돌아오면 해제한 영화가 목록에서 사라지도록 다시 조회한다.
  Future<void> _open(FavoritesViewModel vm, TmdbMovieDto movie) async {
    await widget.onOpenMovie(movie);
    if (!mounted) return;
    await vm.refresh(); // ViewModel이 같은 세션인지 다시 확인한다.
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          appBar: CommonAppBar(
            title: '내 즐겨찾기',
            centerTitle: true,
            onBack: () => context.canPop() ? context.pop() : context.go('/my'),
            actions: [
              if (kDebugMode)
                PopupMenuButton<void>(
                  tooltip: '디버그',
                  icon: const Icon(Icons.bug_report_outlined),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      onTap: () {
                        vm.debugFailNextRefresh();
                        vm.refresh();
                      },
                      child: const Text('목록 조회 실패시키기'),
                    ),
                    PopupMenuItem(
                      onTap: () {
                        vm.debugFailOneMovieOnNextRefresh();
                        vm.refresh();
                      },
                      child: const Text('영화 정보 1건 실패시키기'),
                    ),
                  ],
                ),
            ],
          ),
          body: switch (vm.phase) {
            LoadPhase.idle ||
            LoadPhase.loading =>
              const Center(child: CircularProgressIndicator()),
            LoadPhase.empty => RefreshIndicator(
                onRefresh: vm.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    Icon(Icons.bookmark_border, size: 48),
                    SizedBox(height: 12),
                    Center(child: Text('아직 즐겨찾기한 영화가 없습니다.')),
                  ],
                ),
              ),
            LoadPhase.error => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(vm.errorMessage ?? '조회 오류입니다.'),
                    const SizedBox(height: 16),
                    MovieLogButton(
                      label: '다시 시도',
                      width: 120,
                      onPressed: vm.refresh,
                    ),
                  ],
                ),
              ),
            LoadPhase.ready => RefreshIndicator(
                onRefresh: vm.refresh,
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: vm.items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.55,
                  ),
                  itemBuilder: (context, index) {
                    final item = vm.items[index];
                    final movie = item.movie;
                    // 영화 정보를 못 가져온 카드만 placeholder와 재조회 버튼
                    if (movie == null) {
                      return _MissingMovieCard(
                        item: item,
                        onRetry: () => vm.retryItem(item.favorite.movieId),
                      );
                    }
                    // 기존 영화 카드를 그대로 쓰고, 탭만 "상세 → 돌아오면 재조회"로 바꾼다.
                    return MovieCard(
                      movie: movie,
                      onTap: () => _open(vm, movie),
                    );
                  },
                ),
              ),
          },
        );
      },
    );
  }
}

class _MissingMovieCard extends StatelessWidget {
  const _MissingMovieCard({required this.item, required this.onRetry});

  final FavoriteListItem item;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AspectRatio(
          aspectRatio: 2 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            // posterPath가 null이면 placeholder가 그려진다.
            child: TmdbPosterImage(posterPath: null),
          ),
        ),
        const SizedBox(height: 8),
        Text('영화 #${item.favorite.movieId}', style: textTheme.titleSmall),
        Text(
          item.errorMessage ?? '정보가 없습니다.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
        ),
        const Spacer(),
        MovieLogButton(
          label: '정보 재조회',
          width: double.infinity,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
