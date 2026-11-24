// values를 convert로 바꾸되 동시에 최대 concurrency개만 실행한다. 결과는 입력 순서 그대로다.
// (Future.wait에 전부 넘기면 즐겨찾기 100개면 TMDB 요청 100개가 한꺼번에 나간다)
Future<List<R>> mapBounded<T, R>(
  Iterable<T> values,
  int concurrency,
  Future<R> Function(T value) convert,
) async {
  final input = values.toList(growable: false);
  if (input.isEmpty) return <R>[];
  if (concurrency <= 0) {
    throw ArgumentError.value(concurrency, 'concurrency', 'must be positive');
  }
  final output = List<R?>.filled(input.length, null);
  var next = 0;

  // 각 worker가 다음 순번을 하나씩 가져가 처리한다.
  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= input.length) return;
      output[index] = await convert(input[index]);
    }
  }

  final workers = List.generate(
    concurrency.clamp(1, input.length),
    (_) => worker(),
  );
  await Future.wait(workers);
  return output.cast<R>();
}
