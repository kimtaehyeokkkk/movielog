import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/rating_dialog.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final String movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;
  double? _myRating;

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openRatingDialog() async {
    final rating = await showDialog<double>(
      context: context,
      builder: (context) => RatingDialog(initialRating: _myRating ?? 0),
    );

    if (rating == null || !mounted) return;

    setState(() {
      _myRating = rating;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${rating.toStringAsFixed(1)}점을 남겼습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatCount(int count) {
    return count.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );
  }

  @override
  Widget build(BuildContext context) {
    final movie = findMovieById(int.tryParse(widget.movieId));

    if (movie == null) {
      return Scaffold(
        appBar: CommonAppBar(title: '영화 상세', onBack: () => context.pop()),
        body: const Center(child: Text('영화를 찾을 수 없습니다.')),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: CommonAppBar(
        title: 'Cinema Archive',
        onBack: () => context.pop(),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.asset(movie.posterAsset, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    '${movie.year} · ${movie.genres.join('/')} · ${movie.runtimeMinutes}분',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: movie.rating,
                        itemCount: 5,
                        itemSize: 18,
                        unratedColor: colorScheme.primary.withValues(alpha: 0.2),
                        itemBuilder: (context, index) =>
                            Icon(Icons.star, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${movie.rating.toStringAsFixed(1)} (${_formatCount(movie.ratingCount)})',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (_myRating != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '내 평점 ${_myRating!.toStringAsFixed(1)}점',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in movie.tags) Chip(label: Text(tag)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('시놉시스', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(movie.synopsis, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  label: const Text('즐겨찾기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openRatingDialog,
                  icon: const Icon(Icons.rate_review),
                  label: const Text('평점 남기기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}