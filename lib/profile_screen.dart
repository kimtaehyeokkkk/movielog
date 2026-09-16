import 'package:flutter/material.dart';
import 'package:movielog/theme/app_colors.dart';
import 'package:movielog/theme/app_text_styles.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/stat_item.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(
        title: '내 프로필',
        centerTitle: false,
      ),
      body: const SafeArea(
        child: ProfileBody(),
      ),
    );
  }
}

class ProfileBody extends StatelessWidget {
  const ProfileBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeader(),
            SizedBox(height: 24),
            ProfileStats(),
            SizedBox(height: 24),
            FavoriteGenres(),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

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
        Text('무비러버', style: AppTextStyles.titleLarge),
        const SizedBox(height: 8),
        const Text(
          '매주 주말엔 영화관으로 출근하는 프로 관람객.\n좋은 영화를 보고 기록하는 것을 좋아합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: AppColors.labelGray,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
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