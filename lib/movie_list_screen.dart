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

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadInitialData();
  }

  Future<MovieListInitialData> _loadInitialData() async {
    final results = await Future.wait([
      _movieService.fetchMovies(),
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
      _initialDataFuture = _loadInitialData();
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
      appBar: const CommonAppBar(title: '영화'),
      body: FutureBuilder<MovieListInitialData>(
        future: _initialDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MovieListLoading();
          }

          if (snapshot.hasError) {
            return MovieListError(onRetry: _retry);
          }

          final data = snapshot.data;
          if (data == null) {
            return MovieListError(onRetry: _retry);
          }

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