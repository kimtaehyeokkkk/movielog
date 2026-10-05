import 'package:go_router/go_router.dart';
import 'package:movielog/home_screen.dart';
import 'package:movielog/main_screen.dart';
import 'package:movielog/movie_detail_screen.dart';
import 'package:movielog/movie_list_screen.dart';
import 'package:movielog/profile_screen.dart';
import 'package:movielog/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';

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
                builder: (context, state) => const HomeScreen(),
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