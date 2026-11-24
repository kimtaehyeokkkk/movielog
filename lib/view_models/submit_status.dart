// 쓰기 요청(회원가입·평점 등록) 진행 상태. 여러 ViewModel이 함께 쓴다.
enum SubmitStatus { idle, submitting, success, error }

// 쓰기가 실패했을 때 Dialog에 보여줄 사용자용 문구를 담아 던지는 예외.
// Dialog는 이 예외면 message를 그대로 보여주고, 그 밖의 예외는 일반 문구를 보여준다.
class SubmitFailure implements Exception {
  const SubmitFailure(this.message, {this.closeDialog = false});

  final String message;
  // true면 입력을 고쳐도 해결되지 않는 오류(이미 평점·즐겨찾기 있음, 회원 없음)라
  // Dialog를 닫고 Snackbar로 안내한다. false면 Dialog 안에 문구를 보여주고 입력을 유지한다.
  final bool closeDialog;

  @override
  String toString() => message;
}
