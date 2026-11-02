import 'package:flutter/material.dart';
import 'package:movielog/theme/app_colors.dart';

// 여러 화면이 함께 쓰는 공용 버튼. 상태(통신 중·비활성)와 너비는 화면이 전달하고,
// 버튼은 그 값을 표시만 한다.
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
  });

  final String label;
  // null이면 조건이 충족되지 않은 비활성 상태
  final VoidCallback? onPressed;
  // true면 onPressed와 관계없이 비활성 + 중앙에 인디케이터만 표시
  final bool isLoading;
  // null: 내용 기반 크기 / double.infinity: 부모의 최대 너비 / 고정 값: 항상 그 너비
  final double? width;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          disabledBackgroundColor: AppColors.gray,
          foregroundColor: AppColors.white,
          disabledForegroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // 통신 중에는 label과 인디케이터를 함께 그리지 않고 하나만 그린다.
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
