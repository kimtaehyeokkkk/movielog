import 'package:flutter/material.dart';

class GenreChipBar extends StatelessWidget {
  const GenreChipBar({
    super.key,
    required this.genres,
    required this.selectedGenre,
    required this.onSelected,
  });

  final List<String> genres;
  final String? selectedGenre;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <String?>[null, ...genres];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = items[index];
          return Center(
            child: ChoiceChip(
              label: Text(genre ?? '전체'),
              selected: selectedGenre == genre,
              showCheckmark: false,
              onSelected: (_) => onSelected(genre),
            ),
          );
        },
      ),
    );
  }
}