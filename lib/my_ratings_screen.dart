import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/rating_with_movie.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

// 디버그 메뉴로 재현하는 회원: 평점이 없는 회원(Empty), 존재하지 않는 회원(404 Error)
const _debugEmptyMemberId = 3;
const _debugMissingMemberId = 999999;

class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '내가 등록한 평점',
        centerTitle: true,
        onBack: () =>
            context.canPop() ? context.pop() : context.go('/my'),
        actions: [
          if (kDebugMode)
            PopupMenuButton<int>(
              tooltip: '디버그: 조회 회원 바꾸기',
              icon: const Icon(Icons.bug_report_outlined),
              onSelected: (memberId) => context
                  .read<MyRatingsViewModel>()
                  .debugLoadMember(memberId),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: sampleMemberId,
                  child: Text('memberId 1 (기본)'),
                ),
                PopupMenuItem(
                  value: _debugEmptyMemberId,
                  child: Text('memberId 3 (Empty)'),
                ),
                PopupMenuItem(
                  value: _debugMissingMemberId,
                  child: Text('memberId 999999 (404)'),
                ),
              ],
            ),
        ],
      ),
      // 하단 탭 위가 아니라 root Navigator에 올라오는 화면이라 bottomNavigationBar가 없다.
      body: Consumer<MyRatingsViewModel>(
        builder: (context, viewModel, child) {
          return switch (viewModel.status) {
            MyRatingsLoadStatus.idle ||
            MyRatingsLoadStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            MyRatingsLoadStatus.error => _MyRatingsError(
                message: viewModel.message,
                onRetry: () => context.read<MyRatingsViewModel>().load(),
              ),
            MyRatingsLoadStatus.empty => const _MyRatingsEmpty(),
            MyRatingsLoadStatus.success => _MyRatingsList(
                memberId: viewModel.memberId,
                ratings: viewModel.ratings,
                notice: viewModel.message,
              ),
          };
        },
      ),
    );
  }
}

class _MyRatingsList extends StatelessWidget {
  const _MyRatingsList({
    required this.memberId,
    required this.ratings,
    required this.notice,
  });

  final int memberId;
  final List<RatingWithMovie> ratings;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final notice = this.notice;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // "로그인한 내 평점"으로 오해하지 않도록 조회 대상을 밝힌다.
        Text(
          '학습용 memberId $memberId의 공개 평점 ${ratings.length}개',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (notice != null) ...[
          const SizedBox(height: 8),
          Text(
            notice,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        for (final entry in ratings) _RatingCard(entry: entry),
      ],
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.entry});

  final RatingWithMovie entry;

  String get _date {
    final createdAt = entry.rating.createdAt.toLocal();
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    return '${createdAt.year}.$month.$day';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // TMDB에서 영화를 못 찾았으면 posterPath가 null이라 placeholder가 그려진다.
            child: TmdbPosterImage(
              posterPath: movie?.posterPath,
              width: 64,
              height: 96,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie?.title ?? '영화 정보를 찾을 수 없어요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                Text(
                  'movieId ${rating.movieId}',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(
                        i <= rating.score ? Icons.star : Icons.star_border,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    const SizedBox(width: 4),
                    Text('${rating.score}점', style: textTheme.labelMedium),
                  ],
                ),
                // comment가 null이면 후기 줄을 그리지 않는다.
                if (comment != null) ...[
                  const SizedBox(height: 6),
                  Text(comment, style: textTheme.bodyMedium),
                ],
                const SizedBox(height: 6),
                Text(
                  _date,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRatingsEmpty extends StatelessWidget {
  const _MyRatingsEmpty();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            '아직 등록한 평점이 없어요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _MyRatingsError extends StatelessWidget {
  const _MyRatingsError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message ?? '평점을 불러오지 못했습니다.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            // 고정 너비 예시: 화면 크기와 관계없이 항상 120
            MovieLogButton(label: '다시 시도', width: 120, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
