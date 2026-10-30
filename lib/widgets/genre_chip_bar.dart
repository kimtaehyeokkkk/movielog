import 'package:flutter/material.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';

class GenreChipBar extends StatelessWidget {
  const GenreChipBar({
    super.key,
    required this.genres,
    required this.selectedGenreIds,
    required this.onSelected,
    this.enabled = true,
  });

  final List<TmdbGenreDto> genres;
  // null이면 "전체". BottomSheet로 여러 개를 고르면 해당 Chip이 모두 선택 표시된다.
  final List<int>? selectedGenreIds;
  final ValueChanged<int?> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget chip({required String label, required int? genreId}) {
      final selected = selectedGenreIds;
      final isSelected = genreId == null
          ? selected == null
          : selected?.contains(genreId) ?? false;

      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        selectedColor: colorScheme.primary,
        labelStyle: textTheme.labelLarge?.copyWith(
          color: isSelected
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant,
        ),
        // onSelected가 null이면 Chip이 비활성화된다.
        onSelected: enabled ? (_) => onSelected(genreId) : null,
      );
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) return chip(label: '전체', genreId: null);
          final genre = genres[index - 1];
          return chip(label: genre.name, genreId: genre.id);
        },
      ),
    );
  }
}
