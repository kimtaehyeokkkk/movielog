import 'package:flutter/material.dart';
import 'package:movielog/theme/app_colors.dart';

// 화면 위에 어두운 막과 흰색 인디케이터만 올려 작업이 끝날 때까지 터치를 막는다.
// (흰색 카드나 로딩 문구는 띄우지 않는다)
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          const ModalBarrier(dismissible: false, color: Colors.black45),
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.white),
          ),
      ],
    );
  }
}
