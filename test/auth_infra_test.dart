import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';

import 'support/fake_auth.dart';

const _ratingJson = {
  'ratingId': 7,
  'movieId': 550,
  'score': 5,
  'comment': null,
  'createdAt': '2026-11-16T01:00:00.000Z',
  'updatedAt': '2026-11-16T01:00:00.000Z',
};

Map<String, dynamic> _wrap(Object? result, {String code = 'COMMON200'}) => {
      'isSuccess': true,
      'code': code,
      'message': 'ok',
      'result': result,
    };

// 서버 대신 요청을 가로채 정해진 응답을 돌려주는 Dio. 실제 Interceptor 뒤에 붙여 헤더까지 기록한다.
Dio _dio(
  List<RequestOptions> captured, {
  int statusCode = 200,
  Object? data,
  List<Interceptor> before = const [],
}) {
  return Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
    ..interceptors.addAll([
      ...before,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured.add(options);
          handler.resolve(
            Response(requestOptions: options, statusCode: statusCode, data: data),
          );
        },
      ),
    ]);
}

void main() {
  group('AuthInterceptor', () {
    test('보호 경로에만 Bearer를 붙이고, 공개 경로·다른 host에는 붙이지 않는다', () async {
      final captured = <RequestOptions>[];
      final dio = _dio(
        captured,
        before: [AuthInterceptor(MemoryTokenStorage('token-a'))],
      );

      await dio.get('/v8/members/me');
      await dio.post('/v8/ratings');
      await dio.patch('/v8/ratings/3');
      await dio.post('/v8/auth/login');
      await dio.get('/v8/members/1/ratings');
      await dio.get('https://api.themoviedb.org/3/movie/550');

      final headers = captured.map((o) => o.headers['Authorization']).toList();
      expect(headers.take(3), everyElement('Bearer token-a'));
      expect(headers.skip(3), everyElement(isNull));
    });

    test('토큰이 없으면 헤더 없이 보내고, 이전 요청의 Authorization을 재사용하지 않는다', () async {
      final captured = <RequestOptions>[];
      final dio = _dio(
        captured,
        before: [AuthInterceptor(MemoryTokenStorage())],
      );

      await dio.get(
        '/v8/members/me',
        options: Options(headers: {'Authorization': 'Bearer stale'}),
      );

      expect(captured.single.headers['Authorization'], isNull);
    });

    test('저장소 읽기 실패는 서버 응답 없는 오류로 거절한다', () async {
      final dio = _dio(
        [],
        before: [AuthInterceptor(MemoryTokenStorage()..failRead = true)],
      );

      final error = await dio
          .get('/v8/members/me')
          .then<DioException?>((_) => null, onError: (e) => e as DioException);

      expect(error?.response, isNull);
      expect(error?.error, isA<StateError>());
    });
  });

  group('authRedirect', () {
    test('초기화·재시도 중에는 어디로 가든 스플래시', () {
      expect(authRedirect(AuthStatus.initializing, '/home'), '/start');
      expect(authRedirect(AuthStatus.retryRequired, '/login'), '/start');
      expect(authRedirect(AuthStatus.initializing, '/start'), isNull);
    });

    test('로그아웃 상태는 로그인·회원가입만 허용', () {
      expect(authRedirect(AuthStatus.signedOut, '/my/ratings'), '/login');
      expect(authRedirect(AuthStatus.signedOut, '/start'), '/login');
      expect(authRedirect(AuthStatus.signedOut, '/register'), isNull);
      expect(authRedirect(AuthStatus.authenticating, '/login'), isNull);
    });

    test('로그인 상태에서 스플래시·로그인·회원가입은 홈으로', () {
      expect(authRedirect(AuthStatus.signedIn, '/login'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/start'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/my/profile/edit'), isNull);
    });
  });

  group('v7 Service', () {
    test('로그인 result에서 nickname·accessToken만 읽는다 (memberId 없음)', () async {
      final captured = <RequestOptions>[];
      final service = AuthApiService(
        _dio(captured,
            data: _wrap({'nickname': '태혁', 'accessToken': 'jwt'})),
      );

      final result = await service.login(
        const LoginRequest(email: ' a@umc.com ', password: ' Pw1! '),
      );

      expect(result.accessToken, 'jwt');
      expect(captured.single.uri.path, '/v8/auth/login');
      expect(captured.single.data, {'email': 'a@umc.com', 'password': ' Pw1! '});
    });

    test('내 정보 조회·수정은 공통 응답의 result를 MemberInfo로 읽는다', () async {
      final captured = <RequestOptions>[];
      final service = MemberApiService(
        _dio(captured, data: _wrap({
          'email': 'a@umc.com',
          'nickname': '새닉',
          'createdAt': '2026-10-10T03:00:00.000Z',
        })),
      );

      final me = await service.fetchMe();
      await service.updateNickname('새닉');

      expect(me.nickname, '새닉');
      expect(captured[1].method, 'PATCH');
      expect(captured[1].data, {'nickname': '새닉'});
      expect(() => parseMemberInfo(_wrap(null)), throwsStateError);
    });

    test('평점 쓰기는 보호 Client로 memberId 없는 v7 path에 보내고 result 객체를 읽는다', () async {
      final publicCaptured = <RequestOptions>[];
      final authCaptured = <RequestOptions>[];
      final service = RatingApiService(
        _dio(publicCaptured, data: [_ratingJson]),
        _dio(authCaptured, data: _wrap(_ratingJson, code: 'COMMON201')),
      );

      final created = await service.createRating(
        const CreateRatingRequest(movieId: 550, score: 5),
      );
      final updated = await service.updateRating(
        ratingId: 7,
        request: const UpdateRatingRequest(score: 5, comment: null),
      );
      final list = await service.fetchMemberRatings(1);

      expect(created.ratingId, 7);
      expect(updated.movieId, 550);
      expect(authCaptured[0].uri.path, '/v8/ratings');
      expect(authCaptured[0].data, {'movieId': 550, 'score': 5});
      expect(authCaptured[1].uri.path, '/v8/ratings/7');
      expect(authCaptured[1].data, {'score': 5, 'comment': null});
      // 공개 조회는 공개 Client로 간다.
      expect(publicCaptured.single.uri.path, '/v8/members/1/ratings');
      expect(list.single.ratingId, 7);
    });

    test('삭제는 200 + result null이 성공이고, 204는 예상 밖 응답이다', () async {
      final ok = RatingApiService(
        _dio([]),
        _dio([], data: _wrap(null)),
      );
      await ok.deleteRating(7);

      final unexpected = RatingApiService(_dio([]), _dio([], statusCode: 204));
      expect(() => unexpected.deleteRating(7), throwsStateError);
    });

    test('회원가입·중복 확인은 v7 공개 path', () async {
      final captured = <RequestOptions>[];
      final service = SignUpService(_dio(captured, data: {'available': true}));

      await service.checkNickname('영화광');
      await service.checkEmail('a@umc.com');

      expect(captured[0].uri.path,
          '/v8/members/nickname/%EC%98%81%ED%99%94%EA%B4%91');
      expect(captured[1].uri.path, '/v8/members/email/a%40umc.com');
    });
  });

  group('오류 code', () {
    test('세션 만료는 AUTH401_2/3/4뿐이고, 로그인 실패 AUTH401_1·403은 아니다', () {
      expect(isSessionExpiredError(apiError(401, 'AUTH401_2', '')), isTrue);
      expect(isSessionExpiredError(apiError(401, 'AUTH401_4', '')), isTrue);
      expect(isSessionExpiredError(apiError(401, 'AUTH401_1', '')), isFalse);
      expect(isSessionExpiredError(apiError(403, 'RATING403_1', '')), isFalse);
      expect(isSessionExpiredError(networkError()), isFalse);
    });

    test('가입일은 "yyyy.MM.dd 가입" 형식', () {
      expect(
        formatJoinedDate(DateTime(2026, 10, 10)),
        '2026.10.10 가입',
      );
    });
  });
}
