import 'package:go_router/go_router.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/home_screen.dart';
import 'package:movielog/main_screen.dart';
import 'package:movielog/movie_detail_screen.dart';
import 'package:movielog/movie_list_screen.dart';
import 'package:movielog/profile_screen.dart';
import 'package:movielog/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:provider/provider.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const StartScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const SignUpScreen(),
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
                builder: (context, state) => const MovieListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) => MovieDetailScreen(
          movieId: state.pathParameters['movieId']!,
        ),
      ),
    ],
  );
}