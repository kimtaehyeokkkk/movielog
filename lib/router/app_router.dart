import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/edit_profile_screen.dart';
import 'package:movielog/home_screen.dart';
import 'package:movielog/login_screen.dart';
import 'package:movielog/main_screen.dart';
import 'package:movielog/movie_detail_loader.dart';
import 'package:movielog/movie_list_screen.dart';
import 'package:movielog/movie_search_screen.dart';
import 'package:movielog/favorites_screen.dart';
import 'package:movielog/my_ratings_screen.dart';
import 'package:movielog/profile_screen.dart';
import 'package:movielog/sign_up_screen.dart';
import 'package:movielog/splash_screen.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/session_scoped.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:provider/provider.dart';

// 인증 상태별로 갈 수 있는 화면을 한 곳에서 정한다. 상태만 읽고, 통신 같은 비동기 작업은 하지 않는다.
String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    // 토큰 확인 중 또는 확인 실패(재시도 버튼): 스플래시 유지 (보호 화면을 잠깐이라도 보여주지 않음)
    AuthStatus.initializing ||
    AuthStatus.retryRequired =>
      atStart ? null : '/start',
    // 로그아웃 또는 로그인 요청 중: 공개 화면만 허용
    AuthStatus.signedOut ||
    AuthStatus.authenticating =>
      atPublic ? null : '/login',
    // 로그인됨: 스플래시·로그인·회원가입은 홈으로
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

class AppRouter {
  AppRouter._();

  // 하단 탭(Shell) 밖, 앱 전체의 root Navigator를 가리키는 키
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  // Router가 AuthViewModel을 알아야 상태 변경(refreshListenable)에 반응할 수 있어
  // static final 대신 인스턴스를 받아 만든다. 앱이 살아 있는 동안 한 번만 호출한다.
  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/start',
      navigatorKey: rootNavigatorKey,
      // 인증 상태가 바뀌면 redirect를 다시 실행한다. (로그인·로그아웃·만료가 모두 같은 규칙)
      refreshListenable: authViewModel,
      redirect: (context, state) =>
          authRedirect(authViewModel.status, state.uri.path),
      routes: [
        GoRoute(
          path: '/start', // 스플래시: 토큰 확인 중 / 확인 실패 시 재시도
          builder: (context, state) {
            final auth = context.watch<AuthViewModel>();
            return SplashScreen(
              message: auth.message,
              onRetry: auth.status == AuthStatus.retryRequired
                  ? auth.restoreSession
                  : null,
            );
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
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
                  // 5주차의 최대 30개 수집 대신 첫 page만 불러오고 다음 page는 스크롤로 이어 붙인다.
                  builder: (context, state) =>
                      ChangeNotifierProvider<PagedMoviesViewModel>(
                    create: (context) => PagedMoviesViewModel(
                      tmdbApi: context.read<TmdbMovieService>(),
                    )
                      ..loadGenres()
                      ..loadInitial(),
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
                      // root Navigator 위에 올려 하단 탭을 가린다.
                      parentNavigatorKey: rootNavigatorKey,
                      // 7주차의 memberId 대신, 이번 로그인 세션에서 등록한 평점을 토큰 기반 API로 수정·삭제한다.
                      builder: (context, state) =>
                          ChangeNotifierProvider<MyRatingsViewModel>(
                        create: (context) => MyRatingsViewModel(
                          context.read<RatingApiService>(),
                          context.read<TmdbMovieService>(),
                          context.read<SessionRatings>(),
                          context.read<AuthViewModel>(),
                        )..load(),
                        child: const MyRatingsScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'profile/edit', // 최종 경로: /my/profile/edit
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) => const _EditProfileRoute(),
                    ),
                    GoRoute(
                      path: 'favorites', // 최종 경로: /my/favorites
                      parentNavigatorKey: rootNavigatorKey,
                      // 계정·세션이 바뀌면 ValueKey가 달라져 이전 사용자의 ViewModel을 버린다.
                      // 즐겨찾기 API에는 memberId를 보내지 않고 JWT로 사용자를 구분한다.
                      // email은 화면 쪽 세션 구분에만 쓴다.
                      builder: (context, state) => SessionScoped(
                        title: '내 즐겨찾기',
                        builder: (context, accountId, guard) =>
                            ChangeNotifierProvider<FavoritesViewModel>(
                          key: ValueKey('$accountId:${guard.generation}'),
                          create: (context) => FavoritesViewModel(
                            favoriteApi: context.read<FavoriteApiService>(),
                            tmdbApi: context.read<TmdbMovieService>(),
                            sessionGuard: guard,
                            accountId: accountId,
                            auth: context.read<AuthViewModel>(),
                          ),
                          child: FavoritesScreen(
                            onOpenMovie: (movie) async {
                              await context.push(
                                '/movies/${movie.id}',
                                extra: movie,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // 정적인 search를 동적인 :movieId보다 먼저 등록한다. (반대면 search가 영화 ID로 해석됨)
        GoRoute(
          path: '/movies/search',
          builder: (context, state) => ChangeNotifierProvider<PagedMoviesViewModel>(
            // 영화 목록과 별도의 인스턴스
            create: (context) => PagedMoviesViewModel(
              tmdbApi: context.read<TmdbMovieService>(),
            ),
            child: MovieSearchScreen(
              onOpenMovie: (movie) async {
                await context.push('/movies/${movie.id}', extra: movie);
              },
            ),
          ),
        ),
        GoRoute(
          path: '/movies/:movieId',
          // movieId는 URL 식별자, 화면에 쓸 TmdbMovieDto는 extra로 받는다.
          // extra가 없으면(직접 접근·앱 재시작) Loader가 TMDB 상세 API로 다시 조회한다.
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['movieId'] ?? '');
            if (id == null || id < 1) {
              return Scaffold(
                appBar: CommonAppBar(
                  title: '영화 상세',
                  onBack: () =>
                      context.canPop() ? context.pop() : context.go('/movies'),
                ),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('영화 ID가 올바르지 않습니다.'),
                      const SizedBox(height: 16),
                      MovieLogButton(
                        label: '영화 목록으로',
                        onPressed: () => context.go('/movies'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final extra = state.extra;
            // 즐겨찾기 여부는 사용자별 데이터라 현재 세션이 확인된 뒤에 ViewModel을 만들고,
            // 계정·세션이 바뀌면 ValueKey가 달라져 새로 만든다.
            return SessionScoped(
              title: '영화 상세',
              builder: (context, accountId, guard) =>
                  ChangeNotifierProvider<FavoriteDetailViewModel>(
                key: ValueKey('$accountId:${guard.generation}'),
                create: (context) => FavoriteDetailViewModel(
                  movieId: id,
                  favoriteApi: context.read<FavoriteApiService>(),
                  sessionGuard: guard,
                  accountId: accountId,
                  auth: context.read<AuthViewModel>(),
                ),
                child: MovieDetailLoader(
                  movieId: id,
                  initialMovie:
                      extra is TmdbMovieDto && extra.id == id ? extra : null,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// 프로필 수정은 내 정보(member)가 있어야 시작할 수 있다. 아직 없으면 로딩·재시도를 보여준다.
class _EditProfileRoute extends StatelessWidget {
  const _EditProfileRoute();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (auth.member == null) {
      return Scaffold(
        appBar: CommonAppBar(
          title: '프로필 수정',
          centerTitle: true,
          onBack: () => context.canPop() ? context.pop() : context.go('/my'),
        ),
        body: Center(
          child: auth.memberStatus == MemberLoadStatus.error
              ? MovieLogButton(
                  label: '다시 시도',
                  width: 120,
                  onPressed: () => auth.loadMember(force: true),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    return ChangeNotifierProvider<EditProfileViewModel>(
      create: (context) => EditProfileViewModel(
        context.read<MemberApiService>(),
        context.read<AuthViewModel>(),
      ),
      child: const EditProfileScreen(),
    );
  }
}
