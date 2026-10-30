import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/services/member_service.dart';

enum DuplicateCheckStatus { unchecked, checking, available, duplicated, error }

class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);

  final MemberService _service;

  DuplicateCheckStatus nicknameStatus = DuplicateCheckStatus.unchecked;
  String? nicknameMessage;
  DuplicateCheckStatus emailStatus = DuplicateCheckStatus.unchecked;
  String? emailMessage;

  // 확인 중에 입력이 바뀌면 늦게 온 결과를 버리기 위한 버전
  int _nicknameVersion = 0;
  int _emailVersion = 0;
  bool _disposed = false;

  Future<void> checkNickname(String nickname) async {
    final version = ++_nicknameVersion;
    nicknameStatus = DuplicateCheckStatus.checking;
    nicknameMessage = null;
    notifyListeners();

    final (status, message) = await _check(
      () => _service.isNicknameAvailable(nickname),
      availableMessage: '사용할 수 있는 닉네임이에요.',
      duplicatedMessage: '이미 사용 중인 닉네임이에요.',
    );
    if (_disposed || version != _nicknameVersion) return;

    nicknameStatus = status;
    nicknameMessage = message;
    notifyListeners();
  }

  Future<void> checkEmail(String email) async {
    final version = ++_emailVersion;
    emailStatus = DuplicateCheckStatus.checking;
    emailMessage = null;
    notifyListeners();

    final (status, message) = await _check(
      () => _service.isEmailAvailable(email),
      availableMessage: '사용할 수 있는 이메일이에요.',
      duplicatedMessage: '이미 가입된 이메일이에요.',
    );
    if (_disposed || version != _emailVersion) return;

    emailStatus = status;
    emailMessage = message;
    notifyListeners();
  }

  // 확인한 뒤 입력을 바꾸면 이전 결과는 더 이상 유효하지 않다.
  void resetNickname() {
    if (nicknameStatus == DuplicateCheckStatus.unchecked) return;
    _nicknameVersion++;
    nicknameStatus = DuplicateCheckStatus.unchecked;
    nicknameMessage = null;
    notifyListeners();
  }

  void resetEmail() {
    if (emailStatus == DuplicateCheckStatus.unchecked) return;
    _emailVersion++;
    emailStatus = DuplicateCheckStatus.unchecked;
    emailMessage = null;
    notifyListeners();
  }

  Future<(DuplicateCheckStatus, String)> _check(
    Future<bool> Function() request, {
    required String availableMessage,
    required String duplicatedMessage,
  }) async {
    try {
      final available = await request();
      return available
          ? (DuplicateCheckStatus.available, availableMessage)
          : (DuplicateCheckStatus.duplicated, duplicatedMessage);
    } on DioException catch (error) {
      return (DuplicateCheckStatus.error, movieLogApiErrorMessage(error));
    } catch (error) {
      if (kDebugMode) debugPrint('[SignUp] 응답 변환 실패: $error');
      return (DuplicateCheckStatus.error, '응답을 읽지 못했어요.');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
