import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movielog/theme/app_colors.dart';
import 'package:movielog/widgets/movielog_button.dart';

// 1주차 StartScreen의 로고·제목·설명 레이아웃을 그대로 재사용한 스플래시.
// 하단 '시작하기' 버튼 자리를 세션 확인 상태로 바꿨다.
// - onRetry == null: 저장된 토큰을 확인하는 중 (initializing) → 인디케이터
// - onRetry != null: 확인 실패 (retryRequired) → 안내 문구 + 다시 시도
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'FLUTTER 8주차',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 16 / 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.55,
                  color: Color(0xFF494551),
                ),
              ),
              const SizedBox(height: 40),
              SvgPicture.asset(
                'assets/logos/movielog_logo.svg',
                width: 80,
                height: 80,
                colorFilter: const ColorFilter.mode(
                  AppColors.violet,
                  BlendMode.srcIn,
                ),
                semanticsLabel: 'MovieLog 로고',
              ),
              const SizedBox(height: 40),
              const Text(
                '영화의 순간을\n기록하세요',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 28,
                  height: 36 / 28,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1B1C1A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.25,
                  color: Color(0xFF494551),
                ),
              ),
              const Spacer(),
              if (retry == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                Text(
                  message ?? '로그인 상태를 확인하지 못했어요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF494551)),
                ),
                const SizedBox(height: 12),
                MovieLogButton(
                  label: '다시 시도',
                  width: double.infinity,
                  onPressed: retry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
