import 'package:flutter/material.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

// 입력칸 아래에 중복 확인 결과 문구와 "중복 확인" 버튼을 한 줄로 보여준다.
class DuplicateCheckRow extends StatelessWidget {
  const DuplicateCheckRow({
    super.key,
    required this.status,
    required this.message,
    required this.onCheck,
  });

  final DuplicateCheckStatus status;
  final String? message;
  // null이면 버튼 비활성화 (입력이 형식에 맞지 않을 때)
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final messageColor = switch (status) {
      DuplicateCheckStatus.available => colorScheme.primary,
      DuplicateCheckStatus.duplicated ||
      DuplicateCheckStatus.error =>
        colorScheme.error,
      _ => colorScheme.onSurfaceVariant,
    };

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              message ?? '',
              style: textTheme.bodySmall?.copyWith(color: messageColor),
            ),
          ),
        ),
        if (status == DuplicateCheckStatus.checking)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          TextButton(
            onPressed: onCheck,
            child: const Text('중복 확인'),
          ),
      ],
    );
  }
}
