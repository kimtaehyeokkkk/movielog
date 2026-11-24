import 'package:flutter/material.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:provider/provider.dart';

// 영화 상세 제목 오른쪽의 북마크 버튼.
// 여부 조회·등록·해제 중에는 북마크 자리에만 인디케이터를 보여준다.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key});

  static const _color = Color(0xFF6750A4);

  // 결과는 서버 응답을 기준으로 Snackbar로 안내한다.
  Future<void> _toggle(BuildContext context, FavoriteDetailViewModel vm) async {
    await vm.toggle();
    if (!context.mounted || vm.isDisposed) return;
    final message = vm.errorMessage ??
        (vm.isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoriteDetailViewModel>(
      builder: (context, vm, _) {
        final busy = vm.isLoading || vm.isSaving;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 62,
              height: 48,
              child: busy
                  ? const Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _color,
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: vm.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
                      color: _color,
                      onPressed:
                          vm.hasLoadedStatus ? () => _toggle(context, vm) : null,
                      icon: Icon(
                        vm.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      ),
                    ),
            ),
            Text('즐겨찾기', style: Theme.of(context).textTheme.labelSmall),
            // 첫 여부 조회에 실패했을 때만 다시 확인 버튼을 보여준다.
            if (!vm.hasLoadedStatus && !vm.isLoading)
              SizedBox(
                width: 62,
                child: IconButton(
                  tooltip: '여부 다시 확인',
                  color: _color,
                  onPressed: vm.load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
          ],
        );
      },
    );
  }
}
