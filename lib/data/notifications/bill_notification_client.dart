import 'bill_reminder_batch.dart';

enum BillNotificationPermission {
  unavailable,
  insecure,
  install,
  prompt,
  denied,
  granted;

  static BillNotificationPermission parse(String value) => switch (value) {
    'insecure' => insecure,
    'install' => install,
    'default' => prompt,
    'denied' => denied,
    'granted' => granted,
    _ => unavailable,
  };
}

abstract interface class BillNotificationClient {
  BillNotificationPermission get permission;
  bool activate(String accountKey, {required bool persistent});
  void deactivate(String accountKey);
  void revise(int revision);
  void setEnabled(bool enabled);
  Future<BillNotificationPermission> requestPermission();
  Future<void> prepare();
  Future<bool> showReminder(
    BillReminderBatch batch, {
    required String accountKey,
    required int revision,
  });
  Future<void> showTest();
  Stream<String> get openRequests;
  String? takePendingOpen();
  void dispose();
}
