import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/member_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/home_screen.dart';
import 'package:movielog/main_screen.dart';
import 'package:movielog/movie_detail_screen.dart';
import 'package:movielog/movie_list_screen.dart';
import 'package:movielog/profile_screen.dart';
import 'package:movielog/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:provider/provider.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const StartScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
          create: (context) => SignUpViewModel(context.read<MemberService>()),
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
                builder: (context, state) =>
                    ChangeNotifierProvider<MyRatingsViewModel>(
                  create: (context) => MyRatingsViewModel(
                    context.read<MemberService>(),
                    // TODO(로그인 API): 로그인한 회원 id로 교체. 지금은 서버 시드 데이터의 1번 회원.
                    memberId: 1,
                  )..load(),
                  child: const ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/movies/:movieId',
        // 상세 API가 없어서 목록에서 받은 TmdbMovieDto를 extra로 넘겨받는다.
        builder: (context, state) {
          final extra = state.extra;
          return MovieDetailScreen(
            movieId: int.tryParse(state.pathParameters['movieId']!),
            movie: extra is TmdbMovieDto ? extra : null,
          );
        },
      ),
    ],
  );
}