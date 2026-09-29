import 'package:flutter/material.dart';
import 'package:movielog/widgets/movie_rating_input.dart';

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, this.initialRating = 0});

  final double initialRating;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating = widget.initialRating;
  int _resetCount = 0;

  void _resetRating() {
    setState(() {
      _rating = 0;
      _resetCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('영화는 어떠셨나요?', style: textTheme.titleMedium),
            const SizedBox(height: 24),
            MovieRatingInput(
              key: ValueKey(_resetCount),
              rating: _rating,
              onChanged: (value) {
                setState(() {
                  _rating = value;
                });
              },
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _resetRating,
                child: const Text('다시 선택하기'),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                ),
                onPressed: _rating == 0
                    ? null
                    : () => Navigator.pop(context, _rating),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}