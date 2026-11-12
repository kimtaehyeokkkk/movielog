import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/movie_detail_screen.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:provider/provider.dart';

// 영화 상세의 시작점. 목록에서 넘겨받은 DTO(extra)가 있으면 그대로 쓰고,
// 직접 접근·앱 재시작처럼 extra가 없으면 TMDB GET /movie/{movie_id}로 다시 조회한다.
class MovieDetailLoader extends StatefulWidget {
  const MovieDetailLoader({
    super.key,
    required this.movieId,
    this.initialMovie,
  });

  final int movieId;
  final TmdbMovieDto? initialMovie;

  @override
  State<MovieDetailLoader> createState() => _MovieDetailLoaderState();
}

class _MovieDetailLoaderState extends State<MovieDetailLoader> {
  // build마다 새 Future를 만들지 않도록 initState에서 한 번만 만든다.
  late final Future<TmdbMovieDto> _movieFuture;

  @override
  void initState() {
    super.initState();
    final initialMovie = widget.initialMovie;
    _movieFuture = initialMovie != null
        ? Future.value(initialMovie)
        : context.read<TmdbMovieService>().fetchMovieDetail(widget.movieId);
  }

  void _goBack() =>
      context.canPop() ? context.pop() : context.go('/movies');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TmdbMovieDto>(
      future: _movieFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: CommonAppBar(title: '영화 상세', onBack: _goBack),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final movie = snapshot.data;
        if (snapshot.hasError || movie == null) {
          return Scaffold(
            appBar: CommonAppBar(title: '영화 상세', onBack: _goBack),
            body: const Center(child: Text('영화를 불러오지 못했습니다.')),
          );
        }
        return ChangeNotifierProvider<MovieDetailViewModel>(
          create: (context) => MovieDetailViewModel(
            context.read<RatingApiService>(),
            context.read<LearningMemberSession>().memberId,
            movie,
          ),
          child: const MovieDetailScreen(),
        );
      },
    );
  }
}
