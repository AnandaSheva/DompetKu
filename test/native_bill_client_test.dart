import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dompet_sheva/data/notifications/native_bill_notifications.dart';
import 'package:dompet_sheva/data/notifications/native_bill_schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.sheva.dompetku/test-reminders');
  test(
    'unchanged plans do not repeatedly postpone Android alarms; stale accounts/revisions cannot schedule',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'activate') {
              return {
                'enabled': true,
                'permission': 'granted',
                'recommend': false,
              };
            }
            return null;
          });
      final client = NativeBillNotificationClient(channel: channel);
      addTearDown(() {
        client.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      client.activate('alice', persistent: true);
      await client.prepare();
      client.revise(1);
      const plan = [
        NativeBillReminder(
          day: '2026-12-01',
          phase: 'today',
          keys: ['hashed-occurrence'],
        ),
      ];
      await client.replaceSchedule(plan, accountKey: 'bob', revision: 1);
      await client.replaceSchedule(plan, accountKey: 'alice', revision: 0);
      expect(calls.where((call) => call.method == 'replaceSchedule'), isEmpty);
      await client.replaceSchedule(plan, accountKey: 'alice', revision: 1);
      client.revise(2);
      await client.replaceSchedule(plan, accountKey: 'alice', revision: 2);
      expect(
        calls.where((call) => call.method == 'replaceSchedule'),
        hasLength(1),
      );
      client.setEnabled(false);
      await client.prepare();
      client.deactivate('alice');
      // A new activation awaits cancellation of the previous account first.
      client.activate('bob', persistent: true);
      await client.prepare();
      final names = calls.map((call) => call.method).toList();
      expect(
        names.lastIndexOf('deactivate'),
        lessThan(names.lastIndexOf('activate')),
      );
    },
  );
}
