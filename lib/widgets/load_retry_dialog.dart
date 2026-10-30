import 'package:flutter/material.dart';

// 목록 요청이 실패했지만 최근 목록은 남아 있을 때 띄운다. 재시도면 true, 취소면 false.
class LoadRetryDialog extends StatelessWidget {
  const LoadRetryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.wifi_off_outlined),
      title: const Text('영화를 불러오지 못했어요'),
      content: const Text(
        '네트워크 상태를 확인하고 다시 시도해 주세요.\n'
        '지금 보이는 목록은 마지막으로 불러온 목록이에요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('재시도'),
        ),
      ],
    );
  }
}
