// v5 중복 확인 응답. 공통 Wrapper 없이 body가 곧 결과값이다. ({"available": true})
class CheckResult {
  const CheckResult({required this.available});

  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}
