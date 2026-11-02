import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/services/member_check_service.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

// 입력란 하나의 중복 확인 상태. 닉네임과 이메일이 서로 영향을 주지 않도록 필드마다 따로 둔다.
class _FieldCheck {
  _FieldCheck({required this.duplicatedMessage});

  final String duplicatedMessage;

  CheckStatus status = CheckStatus.idle;
  String? errorText;
  // 서버가 마지막으로 "중복"이라고 답한 값. 같은 값을 다시 입력하면 재요청 없이 바로 에러로 되돌린다.
  String? duplicatedValue;
  String currentValue = '';
  int requestVersion = 0;

  // 통신 중이거나, 중복으로 확인된 값을 바꾸지 않았으면 다시 확인할 수 없다.
  bool get canCheck =>
      status != CheckStatus.checking && status != CheckStatus.duplicated;
}

class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);

  final MemberCheckService _service;

  final _nickname = _FieldCheck(duplicatedMessage: '이미 사용 중인 닉네임입니다.');
  final _email = _FieldCheck(duplicatedMessage: '이미 사용 중인 이메일입니다.');
  bool _disposed = false;

  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;

  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  void onNicknameChanged(String value) => _onChanged(_nickname, value);
  void onEmailChanged(String value) => _onChanged(_email, value);

  Future<void> checkNickname(String value) =>
      _check(_nickname, value, _service.checkNickname);
  Future<void> checkEmail(String value) =>
      _check(_email, value, _service.checkEmail);

  void _onChanged(_FieldCheck field, String value) {
    final trimmed = value.trim();
    if (trimmed == field.currentValue) return;

    field.currentValue = trimmed;
    field.requestVersion++; // 기다리던 이전 응답을 무효화한다.

    if (field.duplicatedValue != null && trimmed == field.duplicatedValue) {
      field.status = CheckStatus.duplicated;
      field.errorText = field.duplicatedMessage;
    } else {
      field.status = CheckStatus.idle;
      field.errorText = null;
    }
    _notify();
  }

  Future<void> _check(
    _FieldCheck field,
    String value,
    Future<bool> Function(String) request,
  ) async {
    final requested = value.trim();
    if (requested.isEmpty ||
        requested != field.currentValue ||
        !field.canCheck) {
      return;
    }

    final version = ++field.requestVersion;
    field.status = CheckStatus.checking;
    field.errorText = null;
    _notify();

    try {
      final available = await request(requested);
      if (_isStale(field, version, requested)) return;

      if (available) {
        field.status = CheckStatus.available;
        field.errorText = null;
      } else {
        field.status = CheckStatus.duplicated;
        field.errorText = field.duplicatedMessage;
        field.duplicatedValue = requested;
      }
    } on DioException {
      // 통신 실패는 서버가 정상 응답한 "중복"과 다른 상태·문구로 보여준다.
      if (_isStale(field, version, requested)) return;
      field.status = CheckStatus.error;
      field.errorText = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
    } catch (error) {
      if (_isStale(field, version, requested)) return;
      if (kDebugMode) debugPrint('[SignUp] 중복 확인 응답 변환 실패: $error');
      field.status = CheckStatus.error;
      field.errorText = '응답을 확인하지 못했습니다. 다시 시도해 주세요.';
    }

    _notify();
  }

  bool _isStale(_FieldCheck field, int version, String requested) =>
      _disposed ||
      version != field.requestVersion ||
      field.currentValue != requested;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nickname.requestVersion++;
    _email.requestVersion++;
    super.dispose();
  }
}
