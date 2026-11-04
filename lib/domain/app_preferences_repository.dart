import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_preferences.dart';

abstract interface class AppPreferencesRepository {
  Future<AppPreferences> load();
  Future<void> save(AppPreferences preferences);
}

class LocalAppPreferencesRepository implements AppPreferencesRepository {
  static const key = 'stride.app.preferences.v1';
  @override
  Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw == null
        ? AppPreferences()
        : AppPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(preferences.toJson()))) {
      throw StateError('Preferences could not be saved');
    }
  }
}
