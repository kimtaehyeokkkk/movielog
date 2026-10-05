import 'package:flutter/material.dart';
import 'package:movielog/models/sort_option.dart';

class SortSelector extends StatelessWidget {
  const SortSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final SortOption selected;
  final ValueChanged<SortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<SortOption>(
        showSelectedIcon: false,
        segments: [
          for (final option in SortOption.values)
            ButtonSegment<SortOption>(
              value: option,
              label: Text(option.label),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    );
  }
}