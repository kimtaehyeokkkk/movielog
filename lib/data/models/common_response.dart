// v6 공통 응답. 쓰기 API의 성공 응답과 모든 API의 실패 응답이 이 형식으로 감싸진다.
// (v5부터 있던 GET 3개는 성공 시 직접 객체·배열 그대로이고, 실패만 이 형식)
class CommonResponse<T> {
  const CommonResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.result,
  });

  final bool isSuccess;
  final String code;
  final String message;
  // API마다 담기는 값이 달라 제네릭. 값이 없거나 실패 응답이면 null
  final T? result;

  // 오류 본문처럼 공통 형식인지 알 수 없는 값을 예외 없이 읽는다. 공통 형식이 아니면 null.
  static CommonResponse<Object?>? tryParse(Object? data) {
    if (data is! Map<String, dynamic>) return null;
    try {
      return CommonResponse<Object?>.fromJson(data, (value) => value);
    } catch (_) {
      return null;
    }
  }

  factory CommonResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? value) parseResult,
  ) {
    final rawResult = json['result'];
    return CommonResponse<T>(
      isSuccess: json['isSuccess'] as bool,
      code: json['code'] as String,
      message: json['message'] as String,
      result: rawResult == null ? null : parseResult(rawResult),
    );
  }
}
