import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/models/movie.dart';
import 'package:movielog/models/sort_option.dart';
import 'package:movielog/services/fake_movie_service.dart';
import 'package:movielog/services/genre_preference.dart';
import 'package:movielog/services/sort_preference.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/genre_chip_bar.dart';
import 'package:movielog/widgets/movie_grid.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';
import 'package:movielog/widgets/sort_selector.dart';

const _allGenre = '전체';
const _requestTimeout = Duration(seconds: 3);

class MovieListInitialData {
  const MovieListInitialData({
    required this.movies,
    required this.selectedGenre,
    required this.selectedSort,
  });

  final List<Movie> movies;
  final String selectedGenre;
  final SortOption selectedSort;
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final _movieService = const FakeMovieService();
  final _genrePreference = GenrePreference();
  final _sortPreference = SortPreference();

  late Future<MovieListInitialData> _initialDataFuture;
  String? _selectedGenre;
  SortOption? _selectedSort;
  MovieLoadMode _mode = MovieLoadMode.success;
  bool _isErrorShown = false;

  // 당겨서 새로고침으로 받아 온 최신 목록. 있으면 FutureBuilder 결과보다 우선한다.
  List<Movie>? _refreshedMovies;

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadInitialData();
  }

  Future<MovieListInitialData> _loadInitialData() async {
    final results = await Future.wait([
      _movieService.fetchMovies(mode: _mode).timeout(_requestTimeout),
      _readGenreOrDefault(),
      _readSortOrDefault(),
    ]);

    return MovieListInitialData(
      movies: results[0] as List<Movie>,
      selectedGenre: results[1] as String,
      selectedSort: results[2] as SortOption,
    );
  }

  // 설정 읽기 실패는 영화 목록 로딩과 분리해 기본값으로 대체한다.
  Future<String> _readGenreOrDefault() async {
    try {
      return await _genrePreference.read();
    } catch (error, stackTrace) {
      debugPrint('장르 설정 읽기 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _allGenre;
    }
  }

  Future<SortOption> _readSortOrDefault() async {
    try {
      return await _sortPreference.read();
    } catch (error, stackTrace) {
      debugPrint('정렬 설정 읽기 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      return SortOption.rating;
    }
  }

  void _retry() {
    setState(() {
      _selectedGenre = null;
      _selectedSort = null;
      _isErrorShown = false;
      _refreshedMovies = null;
      _initialDataFuture = _loadInitialData();
    });
  }

  // 당겨서 새로고침: 화면 전체를 Loading으로 바꾸지 않고 인디케이터만 보여준다.
  Future<void> _refresh() async {
    try {
      final result = await _movieService
          .fetchMovies(mode: _mode)
          .timeout(_requestTimeout);

      if (!mounted) return;

      setState(() {
        _refreshedMovies = result;
      });
    } catch (error, stackTrace) {
      debugPrint('영화 새로고침 실패: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _selectedGenre = null;
        _selectedSort = null;
        _refreshedMovies = null;
        _initialDataFuture = Future<MovieListInitialData>.error(error);
      });
    }
  }

  // 디버그 전용: Error 화면에서는 모드만 바꾸고(다시 시도로 반영),
  // 그 외 화면에서는 즉시 새 요청을 시작한다.
  void _changeMode(MovieLoadMode mode) {
    setState(() {
      _mode = mode;
      if (!_isErrorShown) {
        _selectedGenre = null;
        _selectedSort = null;
        _refreshedMovies = null;
        _initialDataFuture = _loadInitialData();
      }
    });
  }

  Future<void> _selectGenre(String genre) async {
    setState(() {
      _selectedGenre = genre;
    });

    try {
      await _genrePreference.save(genre);
    } catch (error, stackTrace) {
      debugPrint('장르 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _selectSort(SortOption option) async {
    setState(() {
      _selectedSort = option;
    });

    try {
      await _sortPreference.save(option);
    } catch (error, stackTrace) {
      debugPrint('정렬 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  List<Movie> _filter(List<Movie> allMovies, String genre) {
    if (genre == _allGenre) return allMovies;
    return allMovies.where((movie) => movie.genres.contains(genre)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          if (kDebugMode)
            PopupMenuButton<MovieLoadMode>(
              tooltip: '디버그: 로드 모드',
              icon: const Icon(Icons.bug_report_outlined),
              initialValue: _mode,
              onSelected: _changeMode,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: MovieLoadMode.success,
                  child: Text('success'),
                ),
                PopupMenuItem(
                  value: MovieLoadMode.empty,
                  child: Text('empty'),
                ),
                PopupMenuItem(
                  value: MovieLoadMode.failure,
                  child: Text('failure'),
                ),
                PopupMenuItem(
                  value: MovieLoadMode.slow,
                  child: Text('slow (Timeout)'),
                ),
              ],
            ),
        ],
      ),
      body: FutureBuilder<MovieListInitialData>(
        future: _initialDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            _isErrorShown = false;
            return const MovieListLoading();
          }

          if (snapshot.hasError) {
            _isErrorShown = true;
            return MovieListError(
              onRetry: _retry,
              isTimeout: snapshot.error is TimeoutException,
            );
          }

          final data = snapshot.data;
          if (data == null) {
            _isErrorShown = true;
            return MovieListError(onRetry: _retry);
          }

          _isErrorShown = false;
          final currentGenre = _selectedGenre ?? data.selectedGenre;
          final currentSort = _selectedSort ?? data.selectedSort;
          final allMovies = _refreshedMovies ?? data.movies;
          final filtered = currentSort.sort(_filter(allMovies, currentGenre));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GenreChipBar(
                genres: const [_allGenre, ...genreOptions],
                selectedGenre: currentGenre,
                onSelected: _selectGenre,
              ),
              SortSelector(
                selected: currentSort,
                onChanged: _selectSort,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: filtered.isEmpty
                      ? const MovieListEmpty()
                      : MovieGrid(movies: filtered),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}