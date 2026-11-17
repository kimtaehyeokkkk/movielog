import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_with_movie.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/loading_overlay.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/rating_dialog.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MyRatingsViewModel>(
      builder: (context, viewModel, child) {
        // 다중 삭제 중에는 뒤로가기로 화면을 벗어날 수 없다.
        return PopScope(
          canPop: !viewModel.isDeletingSelected,
          child: Scaffold(
            appBar: CommonAppBar(
              title: '내가 등록한 평점',
              centerTitle: true,
              onBack: viewModel.isDeletingSelected
                  ? null
                  : () => context.canPop() ? context.pop() : context.go('/my'),
            ),
            // 하단 탭 위가 아니라 root Navigator에 올라오는 화면이라 bottomNavigationBar가 없다.
            // 다중 선택 중이면서 목록이 있을 때만 하단에 삭제 버튼을 둔다.
            bottomNavigationBar: viewModel.isSelecting &&
                    viewModel.status == MyRatingsLoadStatus.success
                ? _DeleteSelectedBar(viewModel: viewModel)
                : null,
            body: LoadingOverlay(
              isLoading: viewModel.isDeletingSelected,
              child: switch (viewModel.status) {
                MyRatingsLoadStatus.idle ||
                MyRatingsLoadStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
                MyRatingsLoadStatus.empty => const _MyRatingsEmpty(),
                MyRatingsLoadStatus.success =>
                  _MyRatingsList(viewModel: viewModel),
              },
            ),
          ),
        );
      },
    );
  }
}

// --- 수정·삭제 동작 ---

Future<void> _onEditPressed(BuildContext context, RatingDto rating) async {
  final viewModel = context.read<MyRatingsViewModel>();

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막는다.
    builder: (_) => RatingDialog(
      title: '평점 수정',
      initialScore: rating.score,
      initialComment: rating.comment, // null이면 빈 칸으로 시작
      onSubmit: (score, comment) => viewModel.updateRating(
        ratingId: rating.ratingId,
        score: score,
        comment: comment,
      ),
    ),
  );

  if (!context.mounted || saved != true) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('평점을 수정했습니다.')));
}

Future<void> _onDeletePressed(BuildContext context, RatingDto rating) async {
  final viewModel = context.read<MyRatingsViewModel>();

  // 단일 삭제는 삭제 요청이 끝날 때까지 확인 Dialog를 유지한다.
  // confirmed는 실제로 삭제까지 마쳤을 때만 true다.
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteRatingDialog(
      onConfirm: () => viewModel.deleteRating(rating.ratingId),
    ),
  );
}

// Challenge: 다중 삭제는 확인 Dialog를 바로 닫고, 삭제는 화면의 로딩 오버레이 위에서 진행한다.
Future<void> _onDeleteSelectedPressed(BuildContext context) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final count = viewModel.selectedRatingIds.length;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('선택한 평점 $count개를 삭제할까요?'),
      content: const Text('삭제한 평점은 복구할 수 없습니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final failed = await viewModel.deleteSelectedRatings();
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  if (failed > 0) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.'),
      ),
    );
  } else {
    messenger.showSnackBar(
      SnackBar(content: Text('평점 $count개를 삭제했습니다.')),
    );
  }
}

class _DeleteRatingDialog extends StatefulWidget {
  const _DeleteRatingDialog({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<_DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<_DeleteRatingDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: const Text('평점을 삭제할까요?'),
        content: const Text('삭제한 평점은 복구할 수 없습니다.'),
        actions: [
          MovieLogButton(
            label: '취소',
            // 취소하면 onConfirm을 부르지 않으므로 삭제 요청도 없다.
            onPressed:
                _isDeleting ? null : () => Navigator.pop(context, false),
          ),
          MovieLogButton(
            label: '삭제',
            isLoading: _isDeleting,
            onPressed: _isDeleting ? null : _onConfirm,
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirm() async {
    setState(() => _isDeleting = true);
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is SubmitFailure
                ? error.message
                : '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.',
          ),
        ),
      );
    }
  }
}

// --- 목록 ---

class _MyRatingsList extends StatelessWidget {
  const _MyRatingsList({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final notice = viewModel.message;
    final ratings = viewModel.ratings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                viewModel.isSelecting
                    ? '${viewModel.selectedRatingIds.length}개 선택'
                    : '이번 로그인에서 등록한 평점 ${ratings.length}개',
                style: viewModel.isSelecting
                    ? textTheme.titleSmall
                    : textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
              ),
            ),
            // 토큰으로 등록한 평점만 있는 목록이라 모두 본인 평점이다.
            TextButton(
              onPressed: viewModel.isSelecting
                  ? viewModel.cancelSelecting
                  : viewModel.startSelecting,
              child: Text(viewModel.isSelecting ? '취소' : '편집'),
            ),
          ],
        ),
        if (notice != null) ...[
          const SizedBox(height: 4),
          Text(
            notice,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        for (final entry in ratings)
          _RatingCard(
            entry: entry,
            isSelecting: viewModel.isSelecting,
            isSelected:
                viewModel.selectedRatingIds.contains(entry.rating.ratingId),
            onToggle: () => viewModel.toggleSelected(entry.rating.ratingId),
          ),
      ],
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.entry,
    required this.isSelecting,
    required this.isSelected,
    required this.onToggle,
  });

  final RatingWithMovie entry;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onToggle;

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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isSelecting ? onToggle : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : null,
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
                  // TMDB에 없는 영화여도 평점은 지우지 않고 movieId로 대신 표시한다.
                  Text(
                    movie?.title ?? '영화 #${rating.movieId}',
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
            // 다중 선택 중에는 수정·삭제 버튼 대신 CheckBox를 보여준다.
            if (isSelecting)
              Checkbox(value: isSelected, onChanged: (_) => onToggle())
            else
              Column(
                children: [
                  IconButton(
                    tooltip: '수정',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _onEditPressed(context, rating),
                  ),
                  IconButton(
                    tooltip: '삭제',
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    onPressed: () => _onDeletePressed(context, rating),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DeleteSelectedBar extends StatelessWidget {
  const _DeleteSelectedBar({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final count = viewModel.selectedRatingIds.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        // 선택이 1개 이상이고 삭제 중이 아닐 때만 누를 수 있다.
        child: MovieLogButton(
          label: '선택한 $count개 삭제',
          width: double.infinity,
          onPressed: count > 0 && !viewModel.isDeletingSelected
              ? () => _onDeleteSelectedPressed(context)
              : null,
        ),
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
          const SizedBox(height: 8),
          // v7에는 토큰 기반 "내 평점 목록" GET이 없어 이전 로그인에서 남긴 평점은 불러올 수 없다.
          Text(
            '이번 로그인에서 영화 상세의 평점 남기기로 등록한 평점이 여기에 표시돼요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
