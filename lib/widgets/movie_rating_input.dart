import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

// 서버 연동 모드: v6 평점은 1~5 정수라 별 한 개 단위로만 선택한다.
// RatingBar는 항상 double을 돌려주므로 값은 1.0, 2.0처럼 정수를 나타내는 double이다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });

  final double rating;
  final ValueChanged<double> onChanged;
  // false면 저장 중처럼 별점을 바꿀 수 없다.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RatingBar.builder(
      initialRating: rating,
      minRating: 1,
      allowHalfRating: false,
      ignoreGestures: !enabled,
      itemCount: 5,
      itemSize: 40,
      unratedColor: colorScheme.primary.withValues(alpha: 0.2),
      itemBuilder: (context, index) {
        return Icon(Icons.star, color: colorScheme.primary);
      },
      onRatingUpdate: onChanged,
    );
  }
}
