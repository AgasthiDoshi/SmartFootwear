import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress.dart';

class ProgressPreferences {
  const ProgressPreferences({this.goals = const PersonalGoals(), this.quest});
  final PersonalGoals goals;
  final QuestEnrollment? quest;
  Map<String, Object?> toJson() => {
    'goals': goals.toJson(),
    'quest': quest?.toJson(),
  };
  factory ProgressPreferences.fromJson(Map<String, dynamic> json) =>
      ProgressPreferences(
        goals: PersonalGoals.fromJson(json['goals'] as Map<String, dynamic>),
        quest: json['quest'] == null
            ? null
            : QuestEnrollment.fromJson(json['quest'] as Map<String, dynamic>),
      );
}

abstract interface class ProgressRepository {
  Future<ProgressPreferences> load();
  Future<void> save(ProgressPreferences preferences);
}

class LocalProgressRepository implements ProgressRepository {
  static const key = 'stride.progress.v1';
  @override
  Future<ProgressPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw == null
        ? const ProgressPreferences()
        : ProgressPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(ProgressPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(preferences.toJson()))) {
      throw StateError('Could not save progress');
    }
  }
}
