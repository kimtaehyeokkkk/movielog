import 'package:dio/dio.dart';

// v7 오류 응답 {isSuccess, code, message, result}에서 code·message를 꺼낸다.
// 공통 형식이 아니거나 응답이 없으면(네트워크 실패) null.
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}

String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final message = data['message'];
  return message is String ? message : null;
}

// 보호 요청에서 토큰이 없거나(2) 무효하거나(3) 만료된(4) 경우만 세션을 정리한다.
// 로그인 Form의 AUTH401_1(이메일·비밀번호 오류)은 여기에 포함하지 않는다.
const sessionExpiredCodes = {'AUTH401_2', 'AUTH401_3', 'AUTH401_4'};

bool isSessionExpiredError(DioException error) =>
    sessionExpiredCodes.contains(apiErrorCode(error));
