import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/admin_readings.dart';
import '../domain/admin_readings_repository.dart';

class AdminReadingsController extends ChangeNotifier {
  AdminReadingsController({
    this.repository,
    this.unavailableMessage,
  }) {
    _subscription = repository?.watchReadings().listen(
      (readings) {
        value = readings ?? AdminReadings.defaults;
        error = null;
        notifyListeners();
      },
      onError: (Object exception) {
        error = 'Shared readings could not be loaded: $exception';
        notifyListeners();
      },
    );
  }

  final AdminReadingsRepository? repository;
  final String? unavailableMessage;
  late final StreamSubscription<AdminReadings?>? _subscription;
  AdminReadings value = AdminReadings.defaults;
  String? error;
  bool busy = false;
  bool authenticated = false;
  bool get configured => repository != null;

  void updateReadings(AdminReadings readings) {
    value = readings;
    notifyListeners();
  }

  Future<void> sendMotorCommand(String command) async {
    try {
      await repository?.sendMotorCommand(command);
    } catch (e) {
      debugPrint('Error sending motor command: $e');
    }
  }

  void authenticateWithPin() {
    authenticated = true;
    error = null;
    notifyListeners();
  }

  void lockAdminAccess() {
    authenticated = false;
    notifyListeners();
  }

  Future<void> restoreAuthentication() async {
    final store = repository;
    if (store == null || !store.isSignedIn) return;
    busy = true;
    notifyListeners();
    try {
      authenticated = await store.hasAdminRole();
      if (!authenticated) await store.signOut();
    } catch (exception) {
      error = 'Could not verify admin access: $exception';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    final store = repository;
    if (store == null) {
      error =
          unavailableMessage ??
          'Firebase is not configured for this app build.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await store.signIn(email, password);
      authenticated = await store.hasAdminRole();
      if (!authenticated) {
        await store.signOut();
        error = 'This account is not authorized as an administrator.';
      }
      return authenticated;
    } on FirebaseAuthException catch (exception) {
      error = exception.message ?? 'Firebase sign-in failed.';
      return false;
    } catch (exception) {
      error = 'Admin sign-in failed: $exception';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> save(AdminReadings readings) async {
    final store = repository;
    if (!authenticated || store == null) return false;
    if (!readings.valid) {
      error = 'Enter valid values within each reading’s displayed range.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final adjusted = readings.copyWith(adjusted: true);
      await store.save(adjusted);
      value = adjusted;
      notifyListeners();
      return true;
    } catch (exception) {
      error = 'Could not publish adjusted readings: $exception';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> reset() async {
    final store = repository;
    if (!authenticated || store == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await store.reset();
      value = AdminReadings.defaults;
      notifyListeners();
      return true;
    } catch (exception) {
      error = 'Could not reset adjusted readings: $exception';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> triggerRemoteFallAlert() async {
    final newTriggerId = DateTime.now().millisecondsSinceEpoch;
    final updated = value.copyWith(
      fallDetected: true,
      fallTriggerId: newTriggerId,
      adjusted: true,
    );
    value = updated;
    notifyListeners();

    final store = repository;
    if (store != null) {
      try {
        await store.save(updated);
        return true;
      } catch (exception) {
        debugPrint('Firebase remote fall broadcast notice: $exception');
      }
    }
    return true;
  }

  Future<bool> resetRemoteFallAlert() async {
    final updated = value.copyWith(
      fallDetected: false,
    );
    value = updated;
    notifyListeners();

    final store = repository;
    if (store != null) {
      try {
        await store.save(updated);
        return true;
      } catch (_) {}
    }
    return true;
  }

  Future<void> signOut() async {
    authenticated = false;
    await repository?.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
