import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/rating_dialog.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;

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

  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막는다.
      builder: (_) => RatingDialog(
        onSubmit: (score, comment) async {
          await viewModel.createRating(score: score, comment: comment);
          if (viewModel.submitStatus != SubmitStatus.success) {
            // Dialog가 닫히지 않고 이 문구를 보여준다. (입력값 유지)
            throw SubmitFailure(viewModel.submitMessage ?? '저장에 실패했습니다.');
          }
        },
      ),
    );

    // 저장 요청과 Snackbar는 다른 비동기 경계라 await 뒤에 화면이 남아 있는지 다시 확인한다.
    if (!mounted || saved != true) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.'),
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
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final year = _releaseYear(movie);
    final savedScore = viewModel.savedScore;

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
                  if (savedScore != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '내 평점 $savedScore점을 등록했어요',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 학습용 회원가입 전에는 평점을 남길 memberId가 없어 버튼을 끄고 안내한다.
              if (!viewModel.canRate)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '학습용 회원가입을 해야 평점을 남길 수 있어요.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('회원가입'),
                    ),
                  ],
                ),
              Row(
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
                      onPressed: viewModel.canRate ? _openRatingDialog : null,
                      icon: const Icon(Icons.rate_review),
                      label: const Text('평점 남기기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
