import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/models/movie_rating.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/rating_dialog.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.movieId,
    required this.movie,
  });

  // URL의 :movieId (TMDB id)
  final int? movieId;
  // 목록에서 extra로 넘겨받은 영화. 앱 재시작 등으로 extra가 사라지면 null.
  final TmdbMovieDto? movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;
  double? _myRating;

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/movies');
    }
  }

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

  Future<void> _openRatingDialog(TmdbMovieDto movie) async {
    final rating = await showDialog<MovieRating>(
      context: context,
      builder: (context) => RatingDialog(
        movieId: movie.id,
        initialRating: _myRating ?? 0,
      ),
    );

    if (rating == null || !mounted) return;

    // TODO(평점 API): rating.movieId를 CreateRatingRequest.movieId로 전송한다.
    if (kDebugMode) {
      debugPrint('[Rating] movieId=${rating.movieId}, score=${rating.score}');
    }

    setState(() {
      _myRating = rating.score;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${rating.score.toStringAsFixed(1)}점을 남겼습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // release_date가 null이거나 빈 문자열이면 연도를 표시하지 않는다.
  String? _releaseYear(TmdbMovieDto movie) {
    final releaseDate = movie.releaseDate;
    if (releaseDate == null || releaseDate.length < 4) return null;
    return releaseDate.substring(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    if (movie == null || movie.id != widget.movieId) {
      return Scaffold(
        appBar: CommonAppBar(title: '영화 상세', onBack: _goBack),
        body: const Center(child: Text('영화를 찾을 수 없습니다.')),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final year = _releaseYear(movie);

    return Scaffold(
      appBar: CommonAppBar(
        title: 'Cinema Archive',
        onBack: _goBack,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: TmdbPosterImage(posterPath: movie.posterPath),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: textTheme.headlineSmall),
                  if (year != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      year,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // TMDB vote_average는 10점 만점이라 별 5개에 맞춰 절반으로 표시한다.
                      RatingBarIndicator(
                        rating: movie.voteAverage / 2,
                        itemCount: 5,
                        itemSize: 18,
                        unratedColor: colorScheme.primary.withValues(alpha: 0.2),
                        itemBuilder: (context, index) =>
                            Icon(Icons.star, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${movie.voteAverage.toStringAsFixed(1)} / 10',
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
                  const SizedBox(height: 24),
                  Text('시놉시스', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (movie.overview.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '줄거리 정보가 없어요.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(movie.overview, style: textTheme.bodyMedium),
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
                  onPressed: () => _openRatingDialog(movie),
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
