import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bill_notification_client.dart';
import 'bill_reminder_batch.dart';
import 'native_bill_schedule.dart';

Future<void> cancelNativeBillReminders() => const MethodChannel(
  'com.sheva.dompetku/bill_reminders',
).invokeMethod<void>('deactivate');

class NativeBillNotificationClient
    implements BillNotificationClient, ScheduledBillNotificationClient {
  NativeBillNotificationClient({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.sheva.dompetku/bill_reminders') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openBills' && call.arguments is String) {
        _opens.add(call.arguments as String);
        await _channel.invokeMethod<void>('ackOpen', {
          'account': call.arguments,
        });
      }
    });
  }

  final MethodChannel _channel;
  final _opens = StreamController<String>.broadcast();
  String? _account;
  String? _pendingOpen;
  int _revision = 0;
  bool _enabled = false;
  bool _recommend = false;
  String? _lastPlan;
  BillNotificationPermission _permission = BillNotificationPermission.prompt;
  Future<void> _writes = Future.value();

  @override
  bool get enabled => _enabled;
  @override
  BillNotificationPermission get permission =>
      defaultTargetPlatform == TargetPlatform.android
      ? _permission
      : BillNotificationPermission.unavailable;
  @override
  bool activate(String accountKey, {required bool persistent}) {
    if (_account != accountKey) _lastPlan = null;
    _account = accountKey;
    return _enabled;
  }

  @override
  Future<void> prepare() async {
    await _writes;
    final account = _account;
    if (account == null) return;
    final status = await _channel.invokeMapMethod<String, dynamic>('activate', {
      'account': account,
    });
    if (_account != account) return;
    _enabled = status?['enabled'] == true;
    _permission = BillNotificationPermission.parse(
      status?['permission'] as String? ?? 'unavailable',
    );
    _recommend = status?['recommend'] == true;
    _pendingOpen = status?['pendingOpen'] as String?;
  }

  @override
  void revise(int revision) => _revision = revision;
  @override
  void deactivate(String accountKey) {
    if (_account != accountKey) return;
    _account = null;
    _lastPlan = null;
    _writes = _writes
        .catchError((Object _) {})
        .then(
          (_) => _channel.invokeMethod<void>('deactivate', {
            'account': accountKey,
          }),
        )
        .catchError((Object _) {});
  }

  @override
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _lastPlan = null;
    final account = _account;
    _writes = _writes
        .catchError((Object _) {})
        .then(
          (_) => _channel.invokeMethod<void>('setEnabled', {
            'account': account,
            'enabled': enabled,
          }),
        );
    // Scheduling/prepare awaits this future and surfaces failures to the UI.
    unawaited(_writes.catchError((Object _) {}));
  }

  @override
  bool takeRecommendation() {
    if (!_recommend) return false;
    _recommend = false;
    unawaited(
      _channel
          .invokeMethod<void>('dismissRecommendation', {'account': _account})
          .catchError((Object _) {}),
    );
    return true;
  }

  @override
  Future<BillNotificationPermission> requestPermission() async {
    final result = await _channel.invokeMethod<String>('requestPermission');
    return _permission = BillNotificationPermission.parse(
      result ?? 'unavailable',
    );
  }

  @override
  Future<void> replaceSchedule(
    List<NativeBillReminder> reminders, {
    required String accountKey,
    required int revision,
  }) async {
    await _writes;
    if (_account != accountKey || !_enabled || revision != _revision) return;
    final plan = reminders.map((reminder) => reminder.toMap()).toList();
    final signature = jsonEncode(plan);
    if (_lastPlan == signature) return;
    await _channel.invokeMethod<void>('replaceSchedule', {
      'account': accountKey,
      'reminders': plan,
    });
    if (_account == accountKey && revision == _revision) _lastPlan = signature;
  }

  @override
  Future<bool> showReminder(
    BillReminderBatch batch, {
    required String accountKey,
    required int revision,
  }) async => false;
  @override
  Future<void> showTest() async {}
  @override
  Stream<String> get openRequests => _opens.stream;
  @override
  String? takePendingOpen() {
    final result = _pendingOpen;
    _pendingOpen = null;
    return result;
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_opens.close());
  }
}
