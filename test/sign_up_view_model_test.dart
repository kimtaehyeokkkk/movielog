import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';

// 사용 중인 닉네임·이메일 목록으로 응답하는 가짜 Service. 호출 횟수와 실패·지연 주입,
// 회원가입 응답(성공·오류) 주입을 지원한다.
class _FakeMemberCheckService extends SignUpService {
  _FakeMemberCheckService({
    this.takenNicknames = const {},
    this.takenEmails = const {},
  }) : super(Dio());

  final Set<String> takenNicknames;
  final Set<String> takenEmails;
  int nicknameCalls = 0;
  int signUpCalls = 0;
  bool shouldFail = false;
  Completer<bool>? pending;
  // 회원가입 응답: CommonResponse<SignUpResult> 또는 DioException
  Object? signUpResult;

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameCalls++;
    if (shouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v6/members/nickname'),
        type: DioExceptionType.connectionError,
      );
    }
    final pending = this.pending;
    if (pending != null) return pending.future;
    return !takenNicknames.contains(nickname.trim());
  }

  @override
  Future<bool> checkEmail(String email) async {
    return !takenEmails.contains(email.trim());
  }

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUpCalls++;
    final result = signUpResult;
    if (result is DioException) throw result;
    return result as CommonResponse<SignUpResult>;
  }
}

DioException _signUpError(int statusCode, String code, String message) {
  final options = RequestOptions(path: '/v6/members');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: {
        'isSuccess': false,
        'code': code,
        'message': message,
        'result': null,
      },
    ),
    type: DioExceptionType.badResponse,
  );
}

const _request = CreateMemberRequest(
  email: 'taehyeok@umc.com',
  password: 'Umc1234!',
  nickname: '태혁',
);

void main() {
  group('SignUpViewModel 중복 확인', () {
    test('사용 가능하면 available, 에러 문구 없음', () async {
      final viewModel = SignUpViewModel(_FakeMemberCheckService());

      viewModel.onNicknameChanged('태혁');
      await viewModel.checkNickname('태혁');

      expect(viewModel.nicknameCheckStatus, CheckStatus.available);
      expect(viewModel.nicknameErrorText, isNull);
    });

    test('중복이면 duplicated + 에러 문구, 값을 바꾸기 전까지 다시 확인할 수 없다', () async {
      final viewModel =
          SignUpViewModel(_FakeMemberCheckService(takenNicknames: {'영화광'}));

      viewModel.onNicknameChanged('영화광');
      await viewModel.checkNickname('영화광');

      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
      expect(viewModel.canCheckNickname, isFalse);
    });

    test('입력을 바꾸면 idle로 무효화되고, 중복이었던 값을 다시 입력하면 재요청 없이 바로 에러', () async {
      final service = _FakeMemberCheckService(takenNicknames: {'영화광'});
      final viewModel = SignUpViewModel(service);

      viewModel.onNicknameChanged('영화광');
      await viewModel.checkNickname('영화광');

      viewModel.onNicknameChanged('영화광2');
      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      expect(viewModel.nicknameErrorText, isNull);
      expect(viewModel.canCheckNickname, isTrue);

      viewModel.onNicknameChanged(' 영화광 ');
      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
      expect(viewModel.canCheckNickname, isFalse);
      expect(service.nicknameCalls, 1);
    });

    test('통신 실패는 중복과 다른 상태·문구', () async {
      final service = _FakeMemberCheckService()..shouldFail = true;
      final viewModel = SignUpViewModel(service);

      viewModel.onNicknameChanged('태혁');
      await viewModel.checkNickname('태혁');

      expect(viewModel.nicknameCheckStatus, CheckStatus.error);
      expect(viewModel.nicknameErrorText, '중복 확인에 실패했습니다. 다시 시도해 주세요.');
      expect(viewModel.canCheckNickname, isTrue);
    });

    test('확인 중에 입력이 바뀌면 늦게 도착한 응답을 무시한다', () async {
      final service = _FakeMemberCheckService()..pending = Completer<bool>();
      final viewModel = SignUpViewModel(service);

      viewModel.onNicknameChanged('영화광');
      final checking = viewModel.checkNickname('영화광');
      expect(viewModel.nicknameCheckStatus, CheckStatus.checking);

      viewModel.onNicknameChanged('태혁');
      service.pending!.complete(false);
      await checking;

      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      expect(viewModel.nicknameErrorText, isNull);
    });

    test('닉네임과 이메일 결과는 서로 영향을 주지 않는다', () async {
      final viewModel = SignUpViewModel(
        _FakeMemberCheckService(takenEmails: {'movie@umc.com'}),
      );

      viewModel.onNicknameChanged('태혁');
      await viewModel.checkNickname('태혁');
      viewModel.onEmailChanged('movie@umc.com');
      await viewModel.checkEmail('movie@umc.com');

      expect(viewModel.nicknameCheckStatus, CheckStatus.available);
      expect(viewModel.emailCheckStatus, CheckStatus.duplicated);
      expect(viewModel.emailErrorText, '이미 사용 중인 이메일입니다.');
    });
  });

  group('SignUpViewModel 회원가입 제출', () {
    test('201이면 result의 memberId를 읽어 success', () async {
      final service = _FakeMemberCheckService()
        ..signUpResult = const CommonResponse<SignUpResult>(
          isSuccess: true,
          code: 'COMMON201',
          message: '회원가입에 성공했습니다.',
          result: SignUpResult(
            memberId: 42,
            email: 'taehyeok@umc.com',
            nickname: '태혁',
          ),
        );
      final viewModel = SignUpViewModel(service);

      await viewModel.submit(_request);

      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(viewModel.createdMemberId, 42);
    });

    test('비밀번호 형식 400은 비밀번호 칸 errorText로 보낸다', () async {
      const message = '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.';
      final service = _FakeMemberCheckService()
        ..signUpResult = _signUpError(400, 'COMMON400', message);
      final viewModel = SignUpViewModel(service);

      await viewModel.submit(_request);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.passwordErrorText, message);
      expect(viewModel.snackbarMessage, isNull);

      viewModel.onPasswordChanged();
      expect(viewModel.passwordErrorText, isNull);
    });

    test('최종 중복 409는 Snackbar 문구로 보내고 해당 칸을 중복 상태로 되돌린다', () async {
      final service = _FakeMemberCheckService()
        ..signUpResult =
            _signUpError(409, 'COMMON409', '이미 사용 중인 이메일입니다.');
      final viewModel = SignUpViewModel(service);
      viewModel.onEmailChanged(_request.email);
      await viewModel.checkEmail(_request.email);
      expect(viewModel.emailCheckStatus, CheckStatus.available);

      await viewModel.submit(_request);

      expect(viewModel.snackbarMessage, '이미 사용 중인 이메일입니다.');
      expect(viewModel.passwordErrorText, isNull);
      expect(viewModel.emailCheckStatus, CheckStatus.duplicated);
      expect(viewModel.canCheckEmail, isFalse);
    });

    test('memberId가 없는 성공 응답은 가입 완료로 표시하지 않는다', () async {
      final service = _FakeMemberCheckService()
        ..signUpResult = const CommonResponse<SignUpResult>(
          isSuccess: true,
          code: 'COMMON201',
          message: '회원가입에 성공했습니다.',
        );
      final viewModel = SignUpViewModel(service);

      await viewModel.submit(_request);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.createdMemberId, isNull);
      expect(viewModel.snackbarMessage, contains('가입 결과를 확인하지 못했습니다'));
    });

    test('제출 중에는 다시 제출해도 요청을 한 번만 보낸다', () async {
      final service = _FakeMemberCheckService()
        ..signUpResult = const CommonResponse<SignUpResult>(
          isSuccess: true,
          code: 'COMMON201',
          message: '회원가입에 성공했습니다.',
          result: SignUpResult(memberId: 7, email: 'a@umc.com', nickname: '태혁'),
        );
      final viewModel = SignUpViewModel(service);

      final first = viewModel.submit(_request);
      expect(viewModel.isSubmitting, isTrue);
      await viewModel.submit(_request);
      await first;

      expect(service.signUpCalls, 1);
    });
  });
}
