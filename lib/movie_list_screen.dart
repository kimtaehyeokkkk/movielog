import 'package:flutter/material.dart';
import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/genre_chip_bar.dart';
import 'package:movielog/widgets/movie_card.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  String? _selectedGenre;

  @override
  Widget build(BuildContext context) {
    final filteredMovies = _selectedGenre == null
        ? movies
        : movies
            .where((movie) => movie.genres.contains(_selectedGenre))
            .toList();

    return Scaffold(
      appBar: const CommonAppBar(title: '영화'),
      body: Column(
        children: [
          GenreChipBar(
            genres: allGenres,
            selectedGenre: _selectedGenre,
            onSelected: (genre) {
              setState(() {
                _selectedGenre = genre;
              });
            },
          ),
          Expanded(
            child: filteredMovies.isEmpty
                ? const Center(child: Text('해당 장르의 영화가 없습니다.'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filteredMovies.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.55,
                    ),
                    itemBuilder: (context, index) {
                      return MovieCard(movie: filteredMovies[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}