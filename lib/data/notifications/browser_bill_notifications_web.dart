import 'dart:async';
import 'dart:js_interop';

import 'bill_notification_client.dart';
import 'bill_reminder_batch.dart';

@JS('dompetkuBillNotifications')
external _NotificationBridge get _bridge;

extension type _NotificationBridge(JSObject _) implements JSObject {
  external String permission();
  external bool activate(String account, bool persistent);
  external void deactivate(String account);
  external void revise(int revision);
  external void setEnabled(bool enabled);
  external bool takeRecommendation();
  external JSPromise<JSString> requestPermission();
  external JSPromise<JSAny?> prepare();
  external JSPromise<JSBoolean> showReminder(String batch);
  external JSPromise<JSAny?> showTest();
  external void setOpenHandler(JSFunction? callback);
  external String? takePendingOpen();
}

BillNotificationClient createBillNotificationClient() => _BrowserClient();

class _BrowserClient implements BillNotificationClient {
  _BrowserClient() {
    _opens = StreamController<String>.broadcast(
      onListen: () => _bridge.setOpenHandler(
        ((JSString account) => _opens.add(account.toDart)).toJS,
      ),
      onCancel: () => _bridge.setOpenHandler(null),
    );
  }
  late final StreamController<String> _opens;

  @override
  BillNotificationPermission get permission {
    try {
      return BillNotificationPermission.parse(_bridge.permission());
    } catch (_) {
      return BillNotificationPermission.unavailable;
    }
  }

  @override
  bool activate(String accountKey, {required bool persistent}) =>
      _bridge.activate(accountKey, persistent);
  @override
  void deactivate(String accountKey) => _bridge.deactivate(accountKey);
  @override
  void revise(int revision) => _bridge.revise(revision);
  @override
  void setEnabled(bool enabled) => _bridge.setEnabled(enabled);
  @override
  bool takeRecommendation() => _bridge.takeRecommendation();
  @override
  Future<BillNotificationPermission> requestPermission() {
    // Do not await anything before entering the browser permission prompt.
    return _bridge.requestPermission().toDart.then(
      (value) => BillNotificationPermission.parse(value.toDart),
    );
  }

  @override
  Future<void> prepare() async {
    await _bridge.prepare().toDart;
  }

  @override
  Future<bool> showReminder(
    BillReminderBatch batch, {
    required String accountKey,
    required int revision,
  }) async =>
      (await _bridge
              .showReminder(
                batch.toJson(accountKey: accountKey, revision: revision),
              )
              .toDart)
          .toDart;
  @override
  Future<void> showTest() async {
    await _bridge.showTest().toDart;
  }

  @override
  Stream<String> get openRequests => _opens.stream;
  @override
  String? takePendingOpen() => _bridge.takePendingOpen();
  @override
  void dispose() {
    unawaited(_opens.close());
  }
}
