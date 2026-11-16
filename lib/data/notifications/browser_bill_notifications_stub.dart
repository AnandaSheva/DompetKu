import 'bill_notification_client.dart';
import 'bill_reminder_batch.dart';

BillNotificationClient createBillNotificationClient() => _UnavailableClient();

class _UnavailableClient implements BillNotificationClient {
  @override
  BillNotificationPermission get permission =>
      BillNotificationPermission.unavailable;
  @override
  bool activate(String accountKey, {required bool persistent}) => false;
  @override
  void deactivate(String accountKey) {}
  @override
  void revise(int revision) {}
  @override
  void setEnabled(bool enabled) {}
  @override
  bool takeRecommendation() => false;
  @override
  Future<BillNotificationPermission> requestPermission() async => permission;
  @override
  Future<void> prepare() async {}
  @override
  Future<bool> showReminder(
    BillReminderBatch batch, {
    required String accountKey,
    required int revision,
  }) async => false;
  @override
  Future<void> showTest() async {}
  @override
  Stream<String> get openRequests => const Stream.empty();
  @override
  String? takePendingOpen() => null;
  @override
  void dispose() {}
}
