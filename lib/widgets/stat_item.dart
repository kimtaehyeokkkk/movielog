import 'package:flutter/material.dart';
import 'package:movielog/theme/app_colors.dart';

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 114,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statBg,
        border: Border.all(color: AppColors.violetLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
              color: AppColors.labelGray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              height: 28 / 22,
              fontWeight: FontWeight.w700,
              color: AppColors.violetDeep,
            ),
          ),
        ],
      ),
    );
  }
}