import 'package:flutter/material.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/theme/app_text_styles.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:provider/provider.dart';

// 프로필 화면의 "내 평점" 영역. MovieLog 자체 API(유저별 평점 조회) 결과를 보여준다.
class MyRatingsSection extends StatelessWidget {
  const MyRatingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MyRatingsViewModel>(
      builder: (context, viewModel, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        final body = switch (viewModel.status) {
          MyRatingsLoadStatus.idle ||
          MyRatingsLoadStatus.loading =>
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          MyRatingsLoadStatus.error => Column(
              children: [
                Text(
                  viewModel.message ?? '평점을 불러오지 못했어요.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.read<MyRatingsViewModel>().load(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          MyRatingsLoadStatus.empty => Text(
              '아직 남긴 평점이 없어요.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          MyRatingsLoadStatus.success => Column(
              children: [
                for (final rating in viewModel.ratings)
                  _RatingTile(rating: rating),
              ],
            ),
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('내 평점', style: AppTextStyles.titleMedium),
                ),
                if (viewModel.status == MyRatingsLoadStatus.success)
                  Text(
                    '총 ${viewModel.totalElements}개',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            body,
          ],
        );
      },
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({required this.rating});

  final RatingDto rating;

  String? get _date {
    final createdAt = rating.createdAt;
    if (createdAt == null) return null;
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    return '${createdAt.year}.$month.$day';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final comment = rating.comment;
    final date = _date;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 영화 제목은 TMDB에 있고, 서버는 TMDB 영화 id(movieId)만 저장한다.
                Text('영화 #${rating.movieId}', style: textTheme.titleSmall),
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(comment, style: textTheme.bodyMedium),
                ],
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.star, size: 16, color: Colors.amber),
          const SizedBox(width: 2),
          Text(rating.score.toStringAsFixed(1), style: textTheme.labelLarge),
        ],
      ),
    );
  }
}
