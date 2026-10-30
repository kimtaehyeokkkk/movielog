import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/movie_list_screen.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/widgets/load_retry_dialog.dart';
import 'package:provider/provider.dart';

import 'support/fake_tmdb_movie_service.dart';

void main() {
  testWidgets('새로고침 실패 후 재시도도 실패하면 재시도 Dialog를 다시 띄운다', (tester) async {
    final service = FakeTmdbMovieService([
      [1, 2],
    ]);
    final viewModel = MovieListViewModel(service);
    await viewModel.loadInitial();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<MovieListViewModel>.value(
          value: viewModel,
          child: const MovieListScreen(),
        ),
      ),
    );

    service
      ..shouldFail = true
      ..delay = const Duration(milliseconds: 500);
    tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();

    expect(find.byType(LoadRetryDialog), findsOneWidget);
    expect(find.text('영화 1'), findsOneWidget);

    // 재시도 중에는 목록이 Skeleton으로 바뀌었다가 돌아온다. 그래도 Dialog가 다시 떠야 한다.
    await tester.tap(find.text('재시도'));
    await tester.pumpAndSettle();

    expect(find.byType(LoadRetryDialog), findsOneWidget);

    service.shouldFail = false;
    await tester.tap(find.text('재시도'));
    await tester.pumpAndSettle();

    expect(find.byType(LoadRetryDialog), findsNothing);
    expect(find.text('영화 1'), findsOneWidget);
  });
}
