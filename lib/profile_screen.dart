import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/theme/app_colors.dart';
import 'package:movielog/theme/app_text_styles.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/stat_item.dart';
import 'package:provider/provider.dart';

// 마이페이지. MainScreen이 불러온 내 정보(AuthViewModel.member)를 구독해 표시한다.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: CommonAppBar(
        title: '내 프로필',
        centerTitle: false,
        actions: [
          if (kDebugMode)
            PopupMenuButton<void>(
              tooltip: '디버그',
              icon: const Icon(Icons.bug_report_outlined),
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: auth.debugUseInvalidToken,
                  child: const Text('무효 토큰으로 내 정보 요청'),
                ),
              ],
            ),
          // 토큰과 member를 지우면 Router가 /login으로 보낸다.
          TextButton(
            onPressed: auth.storageCleanupInProgress ? null : auth.logout,
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: SafeArea(
        // Challenge: 내 정보를 불러오는 동안 화면 전체 인디케이터, 실패하면 재시도
        child: member != null
            ? ProfileBody(member: member)
            : auth.memberStatus == MemberLoadStatus.error
                ? _MemberLoadError(
                    onRetry: () => auth.loadMember(force: true),
                  )
                : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _MemberLoadError extends StatelessWidget {
  const _MemberLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          const Text('내 정보를 불러오지 못했어요.'),
          const SizedBox(height: 16),
          MovieLogButton(label: '다시 시도', width: 120, onPressed: onRetry),
        ],
      ),
    );
  }
}

class ProfileBody extends StatelessWidget {
  const ProfileBody({super.key, required this.member});

  final MemberInfo member;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeader(member: member),
            const SizedBox(height: 24),
            // 아래 통계·장르는 기존 디자인 예시다. (v7 GET me 응답은 이메일·닉네임·가입일뿐)
            const ProfileStats(),
            const SizedBox(height: 16),
            const MyRatingsEntry(),
            const SizedBox(height: 24),
            const FavoriteGenres(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// 마이페이지 → "내가 등록한 평점" 자식 화면 진입 행
class MyRatingsEntry extends StatelessWidget {
  const MyRatingsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.rate_review_outlined, color: AppColors.violet),
      title: Text('내가 등록한 평점', style: AppTextStyles.titleMedium),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/my/ratings'),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.member});

  final MemberInfo member;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 128,
          height: 128,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.violetBorder, width: 2),
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: ClipOval(
            child: Image.asset(
              'assets/images/profile/profile_movielog.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        Text(member.nickname, style: AppTextStyles.titleLarge),
        const SizedBox(height: 4),
        // Challenge: 닉네임 아래 가입일
        Text(
          formatJoinedDate(member.createdAt),
          style: const TextStyle(
            fontSize: 12,
            height: 16 / 12,
            color: AppColors.labelGray,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          member.email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: AppColors.labelGray,
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.push('/my/profile/edit'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.violet,
            side: const BorderSide(color: AppColors.violet, width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('프로필 수정'),
        ),
      ],
    );
  }
}

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: StatItem(label: '본 영화', value: '342')),
        SizedBox(width: 8),
        Expanded(child: StatItem(label: '평점', value: '4.2')),
        SizedBox(width: 8),
        Expanded(child: StatItem(label: '즐겨찾기', value: '58')),
      ],
    );
  }
}

class FavoriteGenres extends StatelessWidget {
  const FavoriteGenres({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('선호하는 장르', style: AppTextStyles.titleMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _GenreChip(label: '드라마'),
            _GenreChip(label: 'SF'),
            _GenreChip(label: '애니메이션'),
          ],
        ),
      ],
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.violetLight,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: const StadiumBorder(),
    );
  }
}
