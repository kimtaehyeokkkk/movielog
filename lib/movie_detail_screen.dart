import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/favorite_button.dart';
import 'package:movielog/widgets/rating_dialog.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 서버의 즐겨찾기 여부는 화면이 처음 만들어질 때 한 번만 조회한다. (build에서 조회 X)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoriteDetailViewModel>().load();
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/movies');
    }
  }

  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final favorite = context.read<FavoriteDetailViewModel>();
    // 즐겨찾기 여부를 서버에서 확인했고 아직 즐겨찾기하지 않은 영화일 때만 체크박스를 보여준다.
    final showAddToFavorite = favorite.hasLoadedStatus && !favorite.isFavorite;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막는다.
      builder: (_) => RatingDialog(
        showAddToFavorite: showAddToFavorite,
        onSubmit: (score, comment, addToFavorites) async {
          await viewModel.saveRating(
            score: score,
            comment: comment,
            addToFavorites: addToFavorites,
            // Dialog를 연 뒤 여부 조회가 끝났을 수 있어 제출 시점의 값으로 판단한다.
            // 여부를 아직 모르면 movie-records(전체 롤백 위험) 대신 평점 API만 쓴다.
            alreadyFavorite: favorite.isFavorite || !favorite.hasLoadedStatus,
          );
          if (viewModel.submitStatus != SubmitStatus.success) {
            // 입력 오류·네트워크 실패는 Dialog 안에, 409·회원 없음은 Dialog를 닫고 Snackbar로.
            throw SubmitFailure(
              viewModel.submitMessage ?? '저장에 실패했습니다.',
              closeDialog: viewModel.submitClosesDialog,
            );
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
          content: Text('평점을 저장했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    // 함께 즐겨찾기했을 수 있으니 북마크 상태를 서버 값으로 다시 맞춘다.
    favorite.load();
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
                  // 제목·정보 오른쪽에 즐겨찾기(북마크) 버튼
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
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
                                  unratedColor:
                                      colorScheme.primary.withValues(alpha: 0.2),
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
                          ],
                        ),
                      ),
                      const FavoriteButton(),
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
      // 즐겨찾기 버튼이 제목 옆으로 옮겨가 평점 남기기가 전체 너비를 쓴다.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: viewModel.canRate ? _openRatingDialog : null,
            icon: const Icon(Icons.rate_review),
            label: const Text('평점 남기기'),
          ),
        ),
      ),
    );
  }
}
