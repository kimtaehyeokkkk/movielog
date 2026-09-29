import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RatingBar.builder(
      initialRating: rating,
      minRating: 0.5,
      allowHalfRating: true,
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