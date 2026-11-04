import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSecurityService {
  static const String defaultPin = '1234';
  static const String _pinStorageKey = 'smartfootwear_admin_security_pin';

  static bool _sessionUnlocked = false;

  /// Whether admin access has been unlocked in the current session
  static bool get isUnlocked => _sessionUnlocked;

  /// Retrieves the current 4-digit PIN (defaults to '1234')
  static Future<String> getPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_pinStorageKey) ?? defaultPin;
    } catch (e) {
      debugPrint('Error reading admin PIN: $e');
      return defaultPin;
    }
  }

  /// Sets a new 4-digit PIN
  static Future<bool> setPin(String newPin) async {
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinStorageKey, newPin);
      return true;
    } catch (e) {
      debugPrint('Error saving admin PIN: $e');
      return false;
    }
  }

  /// Verifies if the entered PIN matches the stored PIN (or default '1234')
  static Future<bool> verifyPin(String enteredPin) async {
    final storedPin = await getPin();
    final isValid = enteredPin == storedPin || enteredPin == defaultPin;
    if (isValid) {
      _sessionUnlocked = true;
    }
    return isValid;
  }

  /// Locks admin access
  static void lock() {
    _sessionUnlocked = false;
  }

  /// Manually unlocks admin access
  static void unlock() {
    _sessionUnlocked = true;
  }
}
