import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

// 사용 중인 닉네임·이메일 목록으로 응답하는 가짜 Service. 호출 횟수와 실패·지연 주입을 지원한다.
class _FakeMemberCheckService extends MemberCheckService {
  _FakeMemberCheckService({
    this.takenNicknames = const {},
    this.takenEmails = const {},
  }) : super(Dio());

  final Set<String> takenNicknames;
  final Set<String> takenEmails;
  int nicknameCalls = 0;
  bool shouldFail = false;
  Completer<bool>? pending;

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameCalls++;
    if (shouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v5/members/nickname'),
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
}

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
}
