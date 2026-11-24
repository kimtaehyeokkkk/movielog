import 'package:flutter/material.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/widgets/movie_rating_input.dart';
import 'package:movielog/widgets/movielog_button.dart';

// 평점 등록·수정 Dialog. 저장 로직은 onSubmit으로 받아 Dialog 안에서 실행한다.
// onSubmit이 예외 없이 끝나면 true, 취소하면 onSubmit을 부르지 않고 false를 돌려준다.
// 실패하면 Dialog를 닫지 않고 입력값을 그대로 둔 채 오류 문구를 보여준다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    this.initialScore = 0,
    this.initialComment,
    this.title = '평점을 남겨주세요',
    this.showAddToFavorite = false,
    required this.onSubmit,
  });

  // 수정할 때 기존 별점·코멘트로 시작한다. (0이면 아직 별점을 고르지 않은 상태)
  final int initialScore;
  final String? initialComment;
  final String title;
  // Challenge: 상세 화면의 "평점 남기기"에서 아직 즐겨찾기하지 않은 영화일 때만 true.
  // 평점 수정에서도 같은 Dialog를 쓰므로 기본은 숨김이다.
  final bool showAddToFavorite;
  // addToFavorites는 체크박스가 보이지 않으면 항상 false다.
  final Future<void> Function(int score, String? comment, bool addToFavorites)
      onSubmit;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  static const _maxCommentLength = 500;

  late int _score = widget.initialScore;
  // build마다 새로 만들면 별점을 고를 때 입력 중인 코멘트가 사라지므로 State에서 한 번만 만든다.
  late final _commentController =
      TextEditingController(text: widget.initialComment ?? '');
  bool _isSubmitting = false;
  bool _addToFavorites = false;
  String? _errorText;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 저장 중에는 시스템 뒤로가기로 닫히지 않는다. (바깥 탭은 showDialog의 barrierDismissible로 막음)
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: Text(widget.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MovieRatingInput(
                rating: _score.toDouble(),
                enabled: !_isSubmitting,
                onChanged: (value) =>
                    setState(() => _score = validateServerScore(value)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: _maxCommentLength,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  hintText: '코멘트를 남겨보세요 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.showAddToFavorite)
                CheckboxListTile(
                  value: _addToFavorites,
                  onChanged: _isSubmitting
                      ? null
                      : (value) =>
                          setState(() => _addToFavorites = value ?? false),
                  title: const Text('즐겨찾기에도 추가'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          MovieLogButton(
            label: '취소',
            onPressed:
                _isSubmitting ? null : () => Navigator.pop(context, false),
          ),
          // 별점을 고르기 전에는 코멘트만 입력해도 확인할 수 없다.
          MovieLogButton(
            label: '확인',
            isLoading: _isSubmitting,
            onPressed: _score > 0 && !_isSubmitting ? _onConfirm : null,
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirm() async {
    final trimmed = _commentController.text.trim();
    if (trimmed.length > _maxCommentLength) {
      setState(() => _errorText = '코멘트는 500자 이하로 입력해 주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      // 빈 코멘트는 null로 바꿔 보낸다.
      await widget.onSubmit(
        _score,
        trimmed.isEmpty ? null : trimmed,
        widget.showAddToFavorite && _addToFavorites,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      // 다시 시도해도 해결되지 않는 오류는 Dialog를 닫고 Snackbar로 알린다.
      if (error is SubmitFailure && error.closeDialog) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context, false);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
      // 실패해도 로딩을 풀어 다시 시도할 수 있게 하고, 입력한 별점·코멘트는 그대로 둔다.
      setState(() {
        _isSubmitting = false;
        _errorText = error is SubmitFailure
            ? error.message
            : '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }
}
