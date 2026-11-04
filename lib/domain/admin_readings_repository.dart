import 'admin_readings.dart';

abstract interface class AdminReadingsRepository {
  String? get currentUserEmail;
  bool get isSignedIn;
  Stream<AdminReadings?> watchReadings();
  Future<void> signIn(String email, String password);
  Future<bool> hasAdminRole();
  Future<void> signOut();
  Future<void> save(AdminReadings readings);
  Future<void> reset();
  Future<void> sendMotorCommand(String command);
}
