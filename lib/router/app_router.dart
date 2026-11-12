import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/home_screen.dart';
import 'package:movielog/main_screen.dart';
import 'package:movielog/movie_detail_loader.dart';
import 'package:movielog/movie_list_screen.dart';
import 'package:movielog/my_ratings_screen.dart';
import 'package:movielog/profile_screen.dart';
import 'package:movielog/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

class AppRouter {
  AppRouter._();

  // 하단 탭(Shell) 밖, 앱 전체의 root Navigator를 가리키는 키
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    initialLocation: '/start',
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const StartScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
          create: (context) =>
              SignUpViewModel(context.read<SignUpService>()),
          child: const SignUpScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                // indexedStack이라 탭을 오가도 ViewModel이 유지되고, Popular는 한 번만 요청된다.
                builder: (context, state) =>
                    ChangeNotifierProvider<MovieHomeViewModel>(
                  create: (context) => MovieHomeViewModel(
                    context.read<TmdbMovieService>(),
                  )..loadPopular(),
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/movies',
                builder: (context, state) =>
                    ChangeNotifierProvider<MovieListViewModel>(
                  create: (context) => MovieListViewModel(
                    context.read<TmdbMovieService>(),
                  )..loadInitial(),
                  child: const MovieListScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'ratings', // 최종 경로: /my/ratings
                    // Shell(하단 탭)의 Navigator가 아니라 root Navigator 위에 올려 하단 탭을 가린다.
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      // 6주차의 고정 memberId 1 대신 회원가입으로 얻은 학습용 현재 회원을 쓴다.
                      final memberId =
                          context.read<LearningMemberSession>().memberId;
                      if (memberId == null) return const _NeedSignUpScreen();
                      return ChangeNotifierProvider<MyRatingsViewModel>(
                        create: (context) => MyRatingsViewModel(
                          context.read<RatingApiService>(),
                          context.read<TmdbMovieService>(),
                          memberId,
                        )..load(),
                        child: const MyRatingsScreen(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/movies/:movieId',
        // movieId는 URL 식별자, 화면에 쓸 TmdbMovieDto는 extra로 받는다.
        // extra가 없으면(직접 접근·앱 재시작) Loader가 TMDB 상세 API로 다시 조회한다.
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['movieId'] ?? '');
          if (id == null || id < 1) {
            return const Scaffold(
              body: Center(child: Text('영화 ID가 올바르지 않습니다.')),
            );
          }
          final extra = state.extra;
          return MovieDetailLoader(
            movieId: id,
            initialMovie: extra is TmdbMovieDto && extra.id == id ? extra : null,
          );
        },
      ),
    ],
  );
}

// 학습용 회원가입 전에는 조회할 memberId가 없어 안내만 보여준다.
class _NeedSignUpScreen extends StatelessWidget {
  const _NeedSignUpScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '내가 등록한 평점',
        centerTitle: true,
        onBack: () => context.canPop() ? context.pop() : context.go('/my'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('학습용 회원가입이 필요합니다.'),
            const SizedBox(height: 16),
            MovieLogButton(
              label: '회원가입하러 가기',
              onPressed: () => context.go('/register'),
            ),
          ],
        ),
      ),
    );
  }
}