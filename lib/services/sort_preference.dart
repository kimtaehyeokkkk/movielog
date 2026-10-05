import 'package:movielog/models/sort_option.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SortPreference {
  SortPreference({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _selectedSortKey = 'selected_sort';

  final SharedPreferencesAsync _preferences;

  Future<SortOption> read() async {
    final name = await _preferences.getString(_selectedSortKey);
    return SortOption.fromName(name);
  }

  Future<void> save(SortOption option) async {
    await _preferences.setString(_selectedSortKey, option.name);
  }
}