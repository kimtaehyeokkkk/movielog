import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/services/fake_movie_service.dart';

void main() {
  const service = FakeMovieService();

  group('FakeMovieService.fetchMovies', () {
    test('success 모드는 mock 영화 목록을 반환한다', () async {
      final result = await service.fetchMovies(mode: MovieLoadMode.success);

      expect(result, movies);
      expect(result, isNotEmpty);
    });

    test('기본 모드는 success와 같다', () async {
      final result = await service.fetchMovies();

      expect(result, movies);
    });

    test('empty 모드는 빈 목록을 반환한다', () async {
      final result = await service.fetchMovies(mode: MovieLoadMode.empty);

      expect(result, isEmpty);
    });

    test('failure 모드는 MovieLoadException으로 완료된다', () async {
      expect(
        service.fetchMovies(mode: MovieLoadMode.failure),
        throwsA(isA<MovieLoadException>()),
      );
    });

    test('failure 모드의 오류 메시지는 사용자용 문구이다', () async {
      try {
        await service.fetchMovies(mode: MovieLoadMode.failure);
        fail('예외가 발생해야 합니다.');
      } on MovieLoadException catch (error) {
        expect(error.message, '영화를 불러오지 못했습니다.');
      }
    });

    test('success 모드는 최소 800ms 이상 지연된다', () async {
      final stopwatch = Stopwatch()..start();

      await service.fetchMovies(mode: MovieLoadMode.success);

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(800));
    });

    test('slow 모드는 timeout을 걸면 TimeoutException이 발생한다', () async {
      expect(
        service
            .fetchMovies(mode: MovieLoadMode.slow)
            .timeout(const Duration(milliseconds: 1500)),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}