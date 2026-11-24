import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/movie_page_footer.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

// 영화 검색. 영화 목록과는 별도의 PagedMoviesViewModel 인스턴스를 쓴다.
// root Navigator 위에 올라와 하단 탭이 보이지 않는다.
class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({super.key, required this.onOpenMovie});

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  // Challenge: 입력이 500ms 멈추면 마지막 검색어로 한 번만 검색한다.
  static const _debounceDuration = Duration(milliseconds: 500);

  final _text = TextEditingController();
  Timer? _debounce;
  String? _inputError;

  // 제출(키보드 검색·돋보기 버튼). 빈 검색어는 서버에 보내지 않는다.
  void _submitSearch(String value) {
    _debounce?.cancel(); // 제출했으면 기다리던 자동 검색은 필요 없다.
    final query = value.trim();
    if (query.isEmpty) {
      // 빈 검색어는 서버에 보내지 않고, 이전 결과도 지워 처음 상태로 돌린다.
      context.read<PagedMoviesViewModel>().clear();
      setState(() => _inputError = '검색어를 입력해 주세요.');
      return;
    }
    _search(query);
  }

  // Challenge: 입력할 때마다 이전 타이머를 취소하고 500ms 타이머를 새로 시작한다.
  void _onChanged(String value) {
    _debounce?.cancel();
    // 입력을 다 지웠으면 요청 없이 바로 처음 상태로 돌린다. (진행 중이던 검색 응답도 무시)
    if (value.trim().isEmpty) {
      context.read<PagedMoviesViewModel>().clear();
      return;
    }
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      _search(value.trim());
    });
  }

  void _search(String query) {
    if (_inputError != null) setState(() => _inputError = null);
    final vm = context.read<PagedMoviesViewModel>();
    // 같은 검색어가 이미 보이는 중이면 다시 요청하지 않는다.
    if (vm.query == query && vm.phase != LoadPhase.error) return;
    // 새 검색은 이전 결과를 비우고 page 1부터. 이전 검색어의 늦은 응답은 generation으로 버린다.
    vm.loadInitial(query: query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 검색',
        centerTitle: true,
        onBack: () => context.canPop() ? context.pop() : context.go('/movies'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    onSubmitted: _submitSearch,
                    decoration: InputDecoration(
                      labelText: '검색어',
                      hintText: '영화 제목을 입력하세요',
                      errorText: _inputError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '검색',
                  onPressed: () => _submitSearch(_text.text),
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<PagedMoviesViewModel>(
              builder: (context, vm, _) {
                return switch (vm.phase) {
                  // 처음 진입(idle)과 결과 없음(empty)을 구분한다.
                  LoadPhase.idle => const Center(child: Text('검색어를 입력해 주세요.')),
                  LoadPhase.loading =>
                    const Center(child: CircularProgressIndicator()),
                  LoadPhase.error => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(vm.errorMessage ?? '조회 오류입니다.'),
                          const SizedBox(height: 12),
                          MovieLogButton(
                            label: '다시 시도',
                            width: 120,
                            onPressed: vm.refresh,
                          ),
                        ],
                      ),
                    ),
                  LoadPhase.empty => Center(
                      child: Text('"${vm.query}" 검색 결과가 없습니다.'),
                    ),
                  LoadPhase.ready => ListView.builder(
                      itemCount: vm.movies.length + 1,
                      itemBuilder: (context, index) {
                        // 검색 결과는 "더 보기" 버튼으로 이어서 불러온다.
                        if (index == vm.movies.length) {
                          return MoviePageFooter(vm: vm);
                        }
                        final movie = vm.movies[index];
                        final year = (movie.releaseDate?.length ?? 0) >= 4
                            ? movie.releaseDate!.substring(0, 4)
                            : null;
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: TmdbPosterImage(
                              posterPath: movie.posterPath,
                              width: 40,
                              height: 60,
                            ),
                          ),
                          title: Text(movie.title),
                          subtitle: year == null ? null : Text(year),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => widget.onOpenMovie(movie),
                        );
                      },
                    ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}
