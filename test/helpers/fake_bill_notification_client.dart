import 'dart:async';

import 'package:dompet_sheva/data/notifications/bill_notification_client.dart';
import 'package:dompet_sheva/data/notifications/bill_reminder_batch.dart';

class FakeBillNotificationClient implements BillNotificationClient {
  BillNotificationPermission currentPermission =
      BillNotificationPermission.prompt;
  BillNotificationPermission requestedPermission =
      BillNotificationPermission.granted;
  bool enabled = false;
  String? activeAccount;
  int revision = 0;
  int permissionRequests = 0;
  int preparations = 0;
  int testNotifications = 0;
  int activations = 0;
  bool failPreparation = false;
  bool failTest = false;
  Completer<void>? holdPreparation;
  Completer<void>? holdDelivery;
  String? pendingOpen;
  final attempted = <BillReminderBatch>[];
  final delivered = <BillReminderBatch>[];
  final deactivated = <String>[];
  final opens = StreamController<String>.broadcast();

  @override
  BillNotificationPermission get permission => currentPermission;
  @override
  bool activate(String accountKey, {required bool persistent}) {
    activations++;
    activeAccount = accountKey;
    return enabled;
  }

  @override
  void deactivate(String accountKey) {
    deactivated.add(accountKey);
    if (activeAccount == accountKey) activeAccount = null;
  }

  @override
  void revise(int value) => revision = value;
  @override
  void setEnabled(bool value) => enabled = value;
  @override
  Future<BillNotificationPermission> requestPermission() {
    permissionRequests++;
    currentPermission = requestedPermission;
    return Future.value(currentPermission);
  }

  @override
  Future<void> prepare() async {
    preparations++;
    await holdPreparation?.future;
    if (failPreparation) throw StateError('worker unavailable');
  }

  @override
  Future<bool> showReminder(
    BillReminderBatch batch, {
    required String accountKey,
    required int revision,
  }) async {
    attempted.add(batch);
    await holdDelivery?.future;
    if (activeAccount != accountKey ||
        revision != this.revision ||
        !enabled ||
        permission != BillNotificationPermission.granted) {
      return false;
    }
    delivered.add(batch);
    return true;
  }

  @override
  Future<void> showTest() async {
    if (failTest) throw StateError('notifications blocked');
    testNotifications++;
  }

  @override
  Stream<String> get openRequests => opens.stream;
  @override
  String? takePendingOpen() {
    final result = pendingOpen;
    pendingOpen = null;
    return result;
  }

  @override
  void dispose() {
    unawaited(opens.close());
  }
}
