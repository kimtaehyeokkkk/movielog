import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/view_models/submit_status.dart';

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

  final SignUpService _service;

  final _nickname = _FieldCheck(duplicatedMessage: '이미 사용 중인 닉네임입니다.');
  final _email = _FieldCheck(duplicatedMessage: '이미 사용 중인 이메일입니다.');
  bool _disposed = false;

  // 회원가입 POST 상태
  SubmitStatus submitStatus = SubmitStatus.idle;
  // 가입 성공 응답에서 읽은 실제 memberId
  int? createdMemberId;
  // 비밀번호 입력칸에 붙일 서버 오류 (필드 단위)
  String? passwordErrorText;
  // 어느 입력칸에도 붙지 않는 오류 (화면 단위, Snackbar로 한 번 보여준다)
  String? snackbarMessage;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

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

  void onPasswordChanged() {
    if (passwordErrorText == null) return;
    passwordErrorText = null;
    _notify();
  }

  Future<void> submit(CreateMemberRequest request) async {
    if (isSubmitting) return; // 제출 중 중복 탭 방지
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    _notify();

    try {
      final response = await _service.signUp(request);
      if (_disposed) return;
      final id = response.result?.memberId;
      if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      final message = writeSignUpErrorMessage(error);
      final statusCode = error.response?.statusCode;
      if (statusCode == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
        // 중복 확인 직후 다른 사람이 같은 값으로 가입할 수 있어 POST의 409가 최종 중복 결과다.
        if (statusCode == 409) _markDuplicatedFromServer(message, request);
      }
    } catch (error) {
      // memberId가 빠진 응답 등 계약과 다른 성공 응답
      if (_disposed) return;
      if (kDebugMode) debugPrint('[SignUp] 가입 응답 확인 실패: $error');
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    }
    _notify();
  }

  // 409 message로 어느 칸이 중복인지 알 수 있으면 거부된 값을 "중복이었던 값"으로 기억한다.
  // 제출 중에 입력을 바꿨을 수 있으므로, 지금 입력이 거부된 값과 같을 때만 그 칸을 중복 상태로
  // 바꾸고 진행 중인 확인을 무효화한다. 다르면 현재 칸의 상태·오류를 그대로 둔다.
  void _markDuplicatedFromServer(String message, CreateMemberRequest request) {
    final field = message.contains('이메일')
        ? _email
        : message.contains('닉네임')
            ? _nickname
            : null;
    if (field == null) return;
    final value = field == _email ? request.email.trim() : request.nickname.trim();
    field.duplicatedValue = value;
    if (field.currentValue != value) return;
    field
      ..requestVersion += 1
      ..status = CheckStatus.duplicated
      ..errorText = field.duplicatedMessage;
  }

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
