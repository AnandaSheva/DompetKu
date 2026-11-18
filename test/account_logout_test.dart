import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dompet_sheva/data/auth/auth_repository.dart';
import 'package:dompet_sheva/data/auth/browser_session_stub.dart';
import 'package:dompet_sheva/data/auth/web_session_repository.dart';
import 'package:dompet_sheva/data/store/cloud_finance_store.dart';

class _Auth extends Fake implements AuthRepository {
  _Auth(this.actions);
  final List<String> actions;
  @override
  Future<void> signOut() async {
    actions.add('signOut');
  }
}

class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore(this.actions);
  final List<String> actions;
  @override
  Future<void> terminate() async {
    actions.add('terminate');
  }

  @override
  Future<void> clearPersistence() async {
    actions.add('clearCache');
  }
}

class _Store extends Fake implements CloudFinanceStore {
  _Store(this.actions, {this.pending = false});
  final List<String> actions;
  final bool pending;
  @override
  String get uid => 'alice';
  @override
  FirebaseFirestore get firestore => _Firestore(actions);
  @override
  Future<void> waitForSync() async {
    actions.add('waitForSync');
    if (pending) throw StateError('Pending writes');
  }

  @override
  Future<void> close() async {
    actions.add('close');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.sheva.dompetku/bill_reminders');
  test(
    'logout refuses to cancel reminders, close the store, or drop pending writes before sync',
    () async {
      final actions = <String>[];
      SharedPreferences.setMockInitialValues({});
      await initializeSessionStorage();
      savePendingWrites('alice', 'recoverable-pending-write');
      await flushSessionStorage();
      await expectLater(
        endWebSession(_Auth(actions), _Store(actions, pending: true)),
        throwsStateError,
      );
      expect(actions, ['waitForSync']);
      expect(readPendingWrites('alice'), 'recoverable-pending-write');
    },
  );
  test(
    'successful native logout cancels alarms, closes listeners, clears cache/outbox, then signs out',
    () async {
      final actions = <String>[];
      SharedPreferences.setMockInitialValues({});
      await initializeSessionStorage();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            actions.add(call.method);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      savePendingWrites('alice', 'completed-write');
      await endWebSession(_Auth(actions), _Store(actions));
      expect(actions, [
        'waitForSync',
        'deactivate',
        'close',
        'terminate',
        'clearCache',
        'signOut',
      ]);
      await initializeSessionStorage();
      expect(readPendingWrites('alice'), isNull);
    },
  );
}
