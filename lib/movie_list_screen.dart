import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/models/movie.dart';
import 'package:movielog/services/fake_movie_service.dart';
import 'package:movielog/services/genre_preference.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/genre_chip_bar.dart';
import 'package:movielog/widgets/movie_grid.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';

const _allGenre = '전체';
const _requestTimeout = Duration(seconds: 3);

class MovieListInitialData {
  const MovieListInitialData({
    required this.movies,
    required this.selectedGenre,
  });

  final List<Movie> movies;
  final String selectedGenre;
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final _movieService = const FakeMovieService();
  final _genrePreference = GenrePreference();

  late Future<MovieListInitialData> _initialDataFuture;
  String? _selectedGenre;
  MovieLoadMode _mode = MovieLoadMode.success;
  bool _isErrorShown = false;

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadInitialData();
  }

  Future<MovieListInitialData> _loadInitialData() async {
    final results = await Future.wait([
      _movieService.fetchMovies(mode: _mode).timeout(_requestTimeout),
      _genrePreference.read(),
    ]);

    return MovieListInitialData(
      movies: results[0] as List<Movie>,
      selectedGenre: results[1] as String,
    );
  }

  void _retry() {
    setState(() {
      _selectedGenre = null;
      _isErrorShown = false;
      _initialDataFuture = _loadInitialData();
    });
  }

  // 디버그 전용: Error 화면에서는 모드만 바꾸고(다시 시도로 반영),
  // 그 외 화면에서는 즉시 새 요청을 시작한다.
  void _changeMode(MovieLoadMode mode) {
    setState(() {
      _mode = mode;
      if (!_isErrorShown) {
        _selectedGenre = null;
        _initialDataFuture = _loadInitialData();
      }
    });
  }

  Future<void> _selectGenre(String genre) async {
    setState(() {
      _selectedGenre = genre;
    });

    await _genrePreference.save(genre);

    if (!mounted) return;
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
          final filtered = _filter(data.movies, currentGenre);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GenreChipBar(
                genres: const [_allGenre, ...genreOptions],
                selectedGenre: currentGenre,
                onSelected: _selectGenre,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const MovieListEmpty()
                    : MovieGrid(movies: filtered),
              ),
            ],
          );
        },
      ),
    );
  }
}