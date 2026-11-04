import 'sensor.dart';

class AdminReadings {
  const AdminReadings({
    required this.dashboardSteps,
    required this.dailyGoal,
    required this.sensorValues,
    this.adjusted = false,
    this.fallDetected = false,
    this.fallTriggerId = 0,
    this.footContact = false,
    this.mpuStatus = 'Ready',
  });

  static const defaults = AdminReadings(
    dashboardSteps: 6420,
    dailyGoal: 8000,
    sensorValues: SensorFrame.resting,
    fallDetected: false,
    fallTriggerId: 0,
    footContact: false,
    mpuStatus: 'Ready',
  );

  final int dashboardSteps;
  final int dailyGoal;
  final List<double> sensorValues;
  final bool adjusted;
  final bool fallDetected;
  final int fallTriggerId;
  final bool footContact;
  final String mpuStatus;

  int get heelADC => sensorValues.isNotEmpty ? sensorValues[0].round() : 0;
  int get forefootADC => sensorValues.length > 1 ? sensorValues[1].round() : 0;
  int get midfootADC => sensorValues.length > 2 ? sensorValues[2].round() : 0;
  double get accelerationG => sensorValues.length > 5 ? sensorValues[5] : 0.98;
  double get gyroscopeDPS => sensorValues.length > 8 ? sensorValues[8] : 4.70;

  bool get valid =>
      dashboardSteps >= 0 &&
      dashboardSteps <= 1000000 &&
      dailyGoal > 0 &&
      dailyGoal <= 1000000 &&
      sensorValues.length == SensorFrame.labels.length &&
      sensorValues.asMap().entries.every((entry) {
        final index = entry.key;
        final value = entry.value;
        final minimum = index < 3 ? 0.0 : -SensorFrame.limits[index];
        return value.isFinite &&
            value >= minimum &&
            value <= SensorFrame.limits[index];
      });

  AdminReadings copyWith({
    int? dashboardSteps,
    int? dailyGoal,
    List<double>? sensorValues,
    bool? adjusted,
    bool? fallDetected,
    int? fallTriggerId,
    bool? footContact,
    String? mpuStatus,
  }) => AdminReadings(
    dashboardSteps: dashboardSteps ?? this.dashboardSteps,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    sensorValues: List.unmodifiable(sensorValues ?? this.sensorValues),
    adjusted: adjusted ?? this.adjusted,
    fallDetected: fallDetected ?? this.fallDetected,
    fallTriggerId: fallTriggerId ?? this.fallTriggerId,
    footContact: footContact ?? this.footContact,
    mpuStatus: mpuStatus ?? this.mpuStatus,
  );

  factory AdminReadings.fromJson(Map<String, dynamic> json) {
    final readings = AdminReadings(
      dashboardSteps: json['dashboardSteps'] as int,
      dailyGoal: json['dailyGoal'] as int,
      sensorValues: List<double>.unmodifiable(
        (json['sensorValues'] as List)
            .map((value) => (value as num).toDouble()),
      ),
      adjusted: true,
      fallDetected: (json['fallDetected'] as bool?) ?? false,
      fallTriggerId: (json['fallTriggerId'] as num?)?.toInt() ?? 0,
      footContact: (json['footContact'] as bool?) ?? false,
      mpuStatus: (json['mpuStatus'] as String?) ?? 'Ready',
    );
    if (!readings.valid) {
      throw const FormatException('Invalid adjusted readings.');
    }
    return readings;
  }

  Map<String, Object> toJson() => {
    'dashboardSteps': dashboardSteps,
    'dailyGoal': dailyGoal,
    'sensorValues': sensorValues,
    'fallDetected': fallDetected,
    'fallTriggerId': fallTriggerId,
    'footContact': footContact,
    'mpuStatus': mpuStatus,
  };
}
