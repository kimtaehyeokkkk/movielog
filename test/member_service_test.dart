import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/services/member_service.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'support/fake_member_service.dart';

// 서버 대신 요청을 가로채 정해진 응답을 돌려주는 Dio
Dio _dioReturning(Object data, {List<RequestOptions>? captured}) {
  return Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured?.add(options);
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: data),
          );
        },
      ),
    );
}

void main() {
  group('MemberService', () {
    test('한글 닉네임과 @가 들어간 이메일은 인코딩해서 path에 넣는다', () async {
      final captured = <RequestOptions>[];
      final service =
          MemberService(_dioReturning({'available': true}, captured: captured));

      await service.isNicknameAvailable('수현');
      await service.isEmailAvailable('noco@umc.com');

      expect(captured[0].uri.path, '/members/nickname/%EC%88%98%ED%98%84');
      expect(captured[1].uri.path, '/members/email/noco%40umc.com');
    });

    test('평점 조회는 페이지네이션 객체를 RatingPageDto로 바꾼다', () async {
      final service = MemberService(
        _dioReturning({
          'content': [
            {
              'ratingId': 2,
              'movieId': 155,
              'score': 4,
              'comment': '다시 봐도 명작',
              'createdAt': '2026-10-31T01:39:06',
              'updatedAt': '2026-10-31T01:39:06',
            },
          ],
          'page': 0,
          'size': 10,
          'totalElements': 1,
          'totalPages': 1,
          'hasNext': false,
        }),
      );

      final page = await service.fetchRatings(1);

      expect(page.content.single.movieId, 155);
      expect(page.content.single.score, 4.0);
      expect(page.totalElements, 1);
      expect(page.hasNext, isFalse);
    });

    test('서버 오류 응답의 message를 사용자 문구로 쓴다', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/members/nickname/a'),
        response: Response(
          requestOptions: RequestOptions(path: '/members/nickname/a'),
          statusCode: 400,
          data: {'status': 400, 'message': '닉네임은 2~12자여야 합니다.'},
        ),
        type: DioExceptionType.badResponse,
      );

      expect(movieLogApiErrorMessage(error), '닉네임은 2~12자여야 합니다.');
    });
  });

  group('SignUpViewModel', () {
    test('사용 중인 닉네임은 duplicated, 새 닉네임은 available', () async {
      final viewModel =
          SignUpViewModel(FakeMemberService(takenNicknames: {'수현'}));

      await viewModel.checkNickname('수현');
      expect(viewModel.nicknameStatus, DuplicateCheckStatus.duplicated);

      await viewModel.checkNickname('태혁');
      expect(viewModel.nicknameStatus, DuplicateCheckStatus.available);
    });

    test('확인 후 입력이 바뀌면 결과를 지운다', () async {
      final viewModel = SignUpViewModel(FakeMemberService());

      await viewModel.checkEmail('new@umc.com');
      viewModel.resetEmail();

      expect(viewModel.emailStatus, DuplicateCheckStatus.unchecked);
      expect(viewModel.emailMessage, isNull);
    });

    test('서버에 연결하지 못하면 error 상태와 안내 문구', () async {
      final service = FakeMemberService()
        ..error = DioException(
          requestOptions: RequestOptions(path: '/members/email/x'),
          type: DioExceptionType.connectionError,
        );
      final viewModel = SignUpViewModel(service);

      await viewModel.checkEmail('noco@umc.com');

      expect(viewModel.emailStatus, DuplicateCheckStatus.error);
      expect(viewModel.emailMessage, contains('서버에 연결하지 못했어요'));
    });
  });
}
