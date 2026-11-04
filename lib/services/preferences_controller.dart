import 'package:flutter/foundation.dart';
import '../domain/app_preferences.dart';
import '../domain/app_preferences_repository.dart';

class PreferencesController extends ChangeNotifier {
  PreferencesController({
    AppPreferencesRepository? repository,
    DateTime Function()? clock,
  }) : repository = repository ?? LocalAppPreferencesRepository(),
       clock = clock ?? DateTime.now;
  final AppPreferencesRepository repository;
  final DateTime Function() clock;
  AppPreferences data = AppPreferences();
  bool loading = true, saving = false, _loading = false, _disposed = false;
  String? loadError, saveError;
  bool get ready => !loading && loadError == null;
  bool get editable => ready && !saving;
  Future<void> load() async {
    if (_loading || saving) {
      return;
    }
    _loading = true;
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      data = await repository.load();
    } catch (_) {
      loadError =
          'Local profile, contacts and settings could not be read. Retry before making changes.';
    }
    loading = false;
    _loading = false;
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<bool> _save(AppPreferences next) async {
    if (!editable) {
      return false;
    }
    saving = true;
    saveError = null;
    notifyListeners();
    var saved = false;
    try {
      await repository.save(next);
      data = next;
      saved = true;
    } catch (_) {
      saveError =
          'Could not save. Your previously saved data is unchanged. Please retry.';
    }
    saving = false;
    if (!_disposed) {
      notifyListeners();
    }
    return saved;
  }

  Future<bool> setSettings(AppSettings settings) async =>
      settings.valid ? _save(data.copyWith(settings: settings)) : false;
  Future<bool> setProfile(String name) async {
    final profile = LocalProfile(displayName: name.trim());
    if (!profile.valid) {
      saveError = 'Enter a name from 1 to 60 characters.';
      notifyListeners();
      return false;
    }
    return _save(data.copyWith(profile: profile));
  }

  Future<bool> saveContact({
    String? id,
    required String name,
    required String phone,
    String relationship = '',
    bool included = true,
  }) async {
    if (!editable) {
      return false;
    }
    final existing = data.contacts;
    if (id != null && !existing.any((c) => c.id == id)) {
      saveError = 'This contact no longer exists.';
      notifyListeners();
      return false;
    }
    if (id == null && existing.length >= 5) {
      saveError = 'Keep up to 5 contacts. Remove one before adding another.';
      notifyListeners();
      return false;
    }
    var suffix = 0;
    final base = 'contact-${clock().microsecondsSinceEpoch}';
    var nextId = id ?? '$base-${suffix++}';
    while (id == null && existing.any((c) => c.id == nextId)) {
      nextId = '$base-${suffix++}';
    }
    final contact = EmergencyContact(
      id: nextId,
      name: name.trim(),
      phone: phone.trim(),
      relationship: relationship.trim(),
      included: included,
    );
    if (!contact.valid) {
      saveError = 'Check the name and a phone number with 7–15 digits.';
      notifyListeners();
      return false;
    }
    if (existing.any(
      (c) => c.id != id && c.normalizedPhone == contact.normalizedPhone,
    )) {
      saveError = 'A contact with this phone number already exists.';
      notifyListeners();
      return false;
    }
    return _save(
      data.copyWith(contacts: [...existing.where((c) => c.id != id), contact]),
    );
  }

  Future<bool> deleteContact(String id) => _save(
    data.copyWith(contacts: data.contacts.where((c) => c.id != id).toList()),
  );
  Future<bool> clearContacts() => _save(data.copyWith(contacts: const []));
  Future<bool> resetSettings() => setSettings(const AppSettings());
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
