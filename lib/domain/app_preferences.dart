enum PermissionPreview { notRequested, allowed, denied, restricted }

extension PermissionPreviewLabel on PermissionPreview {
  String get label => switch (this) {
    PermissionPreview.notRequested => 'Not requested',
    PermissionPreview.allowed => 'Allowed',
    PermissionPreview.denied => 'Denied',
    PermissionPreview.restricted => 'Restricted',
  };
}

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship = '',
    this.included = true,
  });
  final String id, name, phone, relationship;
  final bool included;
  String get normalizedPhone => phone.replaceAll(RegExp(r'\D'), '');
  String get maskedPhone => normalizedPhone.length < 3
      ? '•••'
      : '••• ${normalizedPhone.substring(normalizedPhone.length - 3)}';
  bool get valid =>
      id.isNotEmpty &&
      validName(name) &&
      validPhone(phone) &&
      relationship.length <= 40 &&
      !RegExp(r'[\x00-\x1f]').hasMatch(relationship);
  static bool validName(String value) =>
      value.trim().isNotEmpty &&
      value.trim().length <= 60 &&
      !RegExp(r'[\x00-\x1f]').hasMatch(value);
  static bool validPhone(String value) =>
      RegExp(r'^\+?[0-9 ()\-]{7,25}$').hasMatch(value.trim()) &&
      value.replaceAll(RegExp(r'\D'), '').length >= 7 &&
      value.replaceAll(RegExp(r'\D'), '').length <= 15;
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relationship': relationship,
    'included': included,
  };
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    final c = EmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String,
      included: json['included'] as bool,
    );
    if (!c.valid) {
      throw const FormatException('Invalid contact');
    }
    return c;
  }
}

class LocalProfile {
  const LocalProfile({this.displayName = 'Smart Footwear Explorer'});
  final String displayName;
  bool get valid => EmergencyContact.validName(displayName);
}

class AppSettings {
  const AppSettings({
    this.countdownSeconds = 10,
    this.testAlertMode = true,
    this.safetyNotices = true,
    this.reminderNotices = false,
    this.maskPhones = true,
    this.retainReplay = true,
    this.reduceMotion = false,
    this.notificationPermission = PermissionPreview.notRequested,
    this.nearbyPermission = PermissionPreview.notRequested,
  });
  final int countdownSeconds;
  final bool testAlertMode,
      safetyNotices,
      reminderNotices,
      maskPhones,
      retainReplay,
      reduceMotion;
  final PermissionPreview notificationPermission, nearbyPermission;
  bool get valid => [5, 10, 20].contains(countdownSeconds);
  AppSettings copyWith({
    int? countdownSeconds,
    bool? testAlertMode,
    bool? safetyNotices,
    bool? reminderNotices,
    bool? maskPhones,
    bool? retainReplay,
    bool? reduceMotion,
    PermissionPreview? notificationPermission,
    PermissionPreview? nearbyPermission,
  }) => AppSettings(
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    testAlertMode: testAlertMode ?? this.testAlertMode,
    safetyNotices: safetyNotices ?? this.safetyNotices,
    reminderNotices: reminderNotices ?? this.reminderNotices,
    maskPhones: maskPhones ?? this.maskPhones,
    retainReplay: retainReplay ?? this.retainReplay,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    notificationPermission:
        notificationPermission ?? this.notificationPermission,
    nearbyPermission: nearbyPermission ?? this.nearbyPermission,
  );
  Map<String, Object> toJson() => {
    'countdown': countdownSeconds,
    'testMode': testAlertMode,
    'safetyNotices': safetyNotices,
    'reminders': reminderNotices,
    'maskPhones': maskPhones,
    'replay': retainReplay,
    'reduceMotion': reduceMotion,
    'notificationPermission': notificationPermission.name,
    'nearbyPermission': nearbyPermission.name,
  };
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final s = AppSettings(
      countdownSeconds: json['countdown'] as int,
      testAlertMode: json['testMode'] as bool,
      safetyNotices: json['safetyNotices'] as bool,
      reminderNotices: json['reminders'] as bool,
      maskPhones: json['maskPhones'] as bool,
      retainReplay: json['replay'] as bool,
      reduceMotion: json['reduceMotion'] as bool,
      notificationPermission: PermissionPreview.values.byName(
        json['notificationPermission'] as String,
      ),
      nearbyPermission: PermissionPreview.values.byName(
        json['nearbyPermission'] as String,
      ),
    );
    if (!s.valid) {
      throw const FormatException('Invalid settings');
    }
    return s;
  }
}

class AppPreferences {
  AppPreferences({
    this.profile = const LocalProfile(),
    this.settings = const AppSettings(),
    List<EmergencyContact> contacts = const [],
  }) : contacts = List.unmodifiable(contacts);
  final LocalProfile profile;
  final AppSettings settings;
  final List<EmergencyContact> contacts;
  AppPreferences copyWith({
    LocalProfile? profile,
    AppSettings? settings,
    List<EmergencyContact>? contacts,
  }) => AppPreferences(
    profile: profile ?? this.profile,
    settings: settings ?? this.settings,
    contacts: contacts ?? this.contacts,
  );
  Map<String, Object> toJson() => {
    'profile': profile.displayName,
    'settings': settings.toJson(),
    'contacts': contacts.map((c) => c.toJson()).toList(),
  };
  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    final p = AppPreferences(
      profile: LocalProfile(displayName: json['profile'] as String),
      settings: AppSettings.fromJson(json['settings'] as Map<String, dynamic>),
      contacts: (json['contacts'] as List)
          .map((v) => EmergencyContact.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
    if (!p.profile.valid ||
        p.contacts.length > 5 ||
        p.contacts.map((c) => c.id).toSet().length != p.contacts.length ||
        p.contacts.map((c) => c.normalizedPhone).toSet().length !=
            p.contacts.length) {
      throw const FormatException('Invalid preferences');
    }
    return p;
  }
}
