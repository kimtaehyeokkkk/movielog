import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/genre_filter_sheet.dart';
import 'package:movielog/widgets/movie_card.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key, required this.selectedGenres});

  final Set<String> selectedGenres;

  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => GenreFilterSheet(
        genres: genreOptions,
        initialSelected: selectedGenres,
      ),
    );

    if (result == null || !context.mounted) return;

    final ordered = genreOptions.where(result.contains).toList();
    final location = Uri(
      path: '/movies',
      queryParameters: ordered.isEmpty ? null : {'genres': ordered.join(',')},
    ).toString();

    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final filteredMovies = selectedGenres.isEmpty
        ? movies
        : movies
            .where((movie) => movie.genres.any(selectedGenres.contains))
            .toList();

    return Scaffold(
      appBar: const CommonAppBar(title: '영화'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: selectedGenres.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          '${selectedGenres.join(', ')} · ${filteredMovies.length}편',
                          style: textTheme.bodyMedium,
                        ),
                ),
                IconButton(
                  tooltip: '장르 필터',
                  onPressed: () => _openFilterSheet(context),
                  icon: Badge(
                    isLabelVisible: selectedGenres.isNotEmpty,
                    label: Text('${selectedGenres.length}'),
                    child: Icon(
                      Icons.filter_list,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
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