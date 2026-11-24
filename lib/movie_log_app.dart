import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/movie_record_api_service.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:provider/provider.dart';

class MovieLogApp extends StatefulWidget {
  const MovieLogApp({super.key});

  @override
  State<MovieLogApp> createState() => _MovieLogAppState();
}

class _MovieLogAppState extends State<MovieLogApp> {
  // Client는 앱이 살아 있는 동안 한 번만 만든다. (build마다 새로 만들지 않음)
  final TokenStorage _tokenStorage =
      SecureTokenStorage(const FlutterSecureStorage());
  late final _publicClient = createMovieLogClient(); // AuthInterceptor 없음
  late final _authClient = createAuthMovieLogClient(_tokenStorage); // 있음

  @override
  Widget build(BuildContext context) {
    // TMDB Client는 TMDB Token만, 워크북 보호용 Client는 MovieLog JWT만 보낸다. (합치지 않음)
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: _tokenStorage),
        Provider<TmdbMovieService>(
          create: (_) => TmdbMovieService(createTmdbClient()),
        ),
        // 공개 Client: 로그인, 회원가입·중복 확인
        Provider<AuthApiService>(
          create: (_) => AuthApiService(_publicClient),
        ),
        Provider<SignUpService>(
          create: (_) => SignUpService(_publicClient),
        ),
        // 보호 Client: 내 정보 / 평점은 공개 조회용 Client도 함께 받는다.
        Provider<MemberApiService>(
          create: (_) => MemberApiService(_authClient),
        ),
        Provider<RatingApiService>(
          create: (_) => RatingApiService(_publicClient, _authClient),
        ),
        // 9주차: 즐겨찾기·영화 기록(Challenge)도 보호 Client (새 Client를 만들지 않음)
        Provider<FavoriteApiService>(
          create: (_) => FavoriteApiService(_authClient),
        ),
        Provider<MovieRecordApiService>(
          create: (_) => MovieRecordApiService(_authClient),
        ),
        // Service를 주입받는 앱 전역 상태
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
          ),
        ),
        ChangeNotifierProvider<SessionRatings>(
          create: (context) => SessionRatings(context.read<AuthViewModel>()),
        ),
        // AuthViewModel의 세션 변화를 SessionGuard에 전달한다.
        // 처음부터 세션 변화를 따라가도록 바로 만든다. (lazy: false)
        Provider<AuthSessionBridge>(
          lazy: false,
          create: (context) {
            final auth = context.read<AuthViewModel>();
            return AuthSessionBridge(
              authSignals: auth,
              sessionVersion: () => auth.sessionVersion,
              verifiedEmail: () =>
                  auth.status == AuthStatus.signedIn ? auth.member?.email : null,
            );
          },
          dispose: (_, bridge) => bridge.dispose(),
        ),
        Provider<SessionGuard>(
          create: (context) => context.read<AuthSessionBridge>().guard,
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

// GoRouter는 한 번만 만들어야 한다. build()에서 만들면 다시 그려질 때마다 위치가 초기화된다.
class _MovieLogRouterApp extends StatefulWidget {
  const _MovieLogRouterApp();

  @override
  State<_MovieLogRouterApp> createState() => _MovieLogRouterAppState();
}

class _MovieLogRouterAppState extends State<_MovieLogRouterApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authViewModel = context.read<AuthViewModel>();
    _router = AppRouter.createRouter(authViewModel);
    // 첫 build 이후 세션 복원을 시작한다. (그동안 스플래시가 보인다)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) authViewModel.restoreSession();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
