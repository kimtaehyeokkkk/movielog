// 쓰기 요청(회원가입·평점 등록) 진행 상태. 여러 ViewModel이 함께 쓴다.
enum SubmitStatus { idle, submitting, success, error }

// 쓰기가 실패했을 때 Dialog에 보여줄 사용자용 문구를 담아 던지는 예외.
// Dialog는 이 예외면 message를 그대로 보여주고, 그 밖의 예외는 일반 문구를 보여준다.
class SubmitFailure implements Exception {
  const SubmitFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
