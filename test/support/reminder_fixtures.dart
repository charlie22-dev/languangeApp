import 'package:myapp/features/notifications/data/reminder_service.dart';

class TestReminderService extends ReminderService {
  bool allowed = true;
  int permissionRequests = 0;
  final calls = <({String? userId, bool enabled, bool goalDone})>[];
  @override
  bool get supported => true;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }

  @override
  Future<void> reconcile({
    required String? userId,
    required bool enabled,
    required int hour,
    required int minute,
    required bool sound,
    required bool goalDone,
    bool force = false,
  }) async {
    calls.add((userId: userId, enabled: enabled, goalDone: goalDone));
  }
}
