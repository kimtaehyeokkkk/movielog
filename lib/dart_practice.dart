import 'package:flutter/foundation.dart';
import 'movie.dart';

void runDartPractice() {
  final movies = <Movie>[
    const Movie(id: 1, title: '분노의 질주'),
    const Movie(id: 2, title: '미션임파서블'),
    const Movie(id: 3, title: '만약에 우리'),
  ];

  for (final movie in movies) {
    debugPrintMovie(movie.title);
  }

  movies.map((m) => m.title).forEach(debugPrintMovie);
  debugPrint(displayName(null));
  debugPrint(displayName('  '));
  debugPrint(displayName('무비러버'));
}

void debugPrintMovie(String title) {
  debugPrint('영화 제목: $title');
}

String displayName(String? nickname) {
  return nickname?.trim().isNotEmpty == true ? nickname! : '이름 없음';
}