import 'package:flutter/material.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';

// 목록 맨 아래: 더 보기 / 추가 로딩 / 다음 page 실패 시 같은 page 재시도 / 끝
// autoLoad가 true면(무한 스크롤, Challenge) 더 보기 버튼 없이 스크롤로 다음 page를 부르고,
// 실패했을 때만 다시 시도 버튼을 보여준다.
class MoviePageFooter extends StatelessWidget {
  const MoviePageFooter({super.key, required this.vm, this.autoLoad = false});

  final PagedMoviesViewModel vm;
  final bool autoLoad;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final error = vm.loadMoreError;

    if (!vm.hasMore && !vm.isLoadingMore && error == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '더 이상 조회할 페이지가 없습니다.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (autoLoad && error == null) {
      return const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (error != null) ...[
            Text(
              error,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          MovieLogButton(
            width: double.infinity,
            label: error == null ? '더 보기' : '다음 페이지 다시 시도',
            isLoading: vm.isLoadingMore,
            onPressed: vm.phase == LoadPhase.ready ? vm.loadNextPage : null,
          ),
        ],
      ),
    );
  }
}
