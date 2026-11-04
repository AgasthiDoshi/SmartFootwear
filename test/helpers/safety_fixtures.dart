import 'dart:async';
import 'package:stride_ai/domain/app_preferences.dart';
import 'package:stride_ai/domain/app_preferences_repository.dart';
import 'package:stride_ai/domain/safety/safety_models.dart';
import 'package:stride_ai/domain/safety/device_preview.dart';

class MemoryAppPreferences implements AppPreferencesRepository {
  AppPreferences data = AppPreferences();
  bool failLoad = false, failSave = false;
  @override
  Future<AppPreferences> load() async {
    if (failLoad) {
      throw StateError('Read failed');
    }
    return data;
  }

  @override
  Future<void> save(AppPreferences next) async {
    if (failSave) {
      throw StateError('Write failed');
    }
    data = next;
  }
}

const testContact = EmergencyContact(
  id: 'contact-one',
  name: 'Demo Friend',
  phone: '+91 98765 43210',
  relationship: 'Friend',
);

class SpyEmergencyPreview implements EmergencyPreviewPort {
  final List<EmergencyPreviewRequest> requests = [];
  bool fail = false;
  Completer<EmergencyPreviewReceipt>? deferred;
  @override
  Future<EmergencyPreviewReceipt> preview(
    EmergencyPreviewRequest request,
  ) async {
    requests.add(request);
    if (fail) {
      throw StateError('Preview failed');
    }
    if (deferred != null) {
      return deferred!.future;
    }
    return EmergencyPreviewReceipt(request.recipientCount);
  }
}

class SpyHaptics implements HapticPreviewPort {
  final List<HapticPattern> requests = [];
  Completer<HapticPreviewReceipt>? deferred;
  @override
  Future<HapticPreviewReceipt> preview(HapticPattern pattern) async {
    requests.add(pattern);
    return deferred == null
        ? HapticPreviewReceipt(pattern.command)
        : deferred!.future;
  }
}
