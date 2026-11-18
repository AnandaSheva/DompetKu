import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dompet_sheva/app/providers/auth_providers.dart';
import 'package:dompet_sheva/app/providers/bill_reminder_providers.dart';
import 'package:dompet_sheva/app/providers/planning_providers.dart';
import 'package:dompet_sheva/data/auth/auth_repository.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/notifications/bill_notification_client.dart';
import 'package:dompet_sheva/data/notifications/native_bill_schedule.dart';
import 'package:dompet_sheva/data/store/cloud_finance_store.dart';
import 'helpers/fake_bill_notification_client.dart';
import 'helpers/financial_calendar_fixture.dart';

class _Scheduler extends FakeBillNotificationClient
    implements ScheduledBillNotificationClient {
  final replacements = <List<NativeBillReminder>>[];
  @override
  Future<void> replaceSchedule(
    List<NativeBillReminder> reminders, {
    required String accountKey,
    required int revision,
  }) async {
    if (enabled && activeAccount == accountKey && revision == this.revision) {
      replacements.add(reminders);
    }
  }
}

void main() {
  test(
    'native alarms use synchronized data, replace changed schedules, and cancel on logout',
    () async {
      final client = _Scheduler();
      final bills = StreamController<List<RecurringBillEntry>>.broadcast();
      final statuses = StreamController<CloudStatus>.broadcast();
      final container = ProviderContainer(
        overrides: [
          webPlatformProvider.overrideWithValue(false),
          currentAccountProvider.overrideWithValue(
            const AppAccount(uid: 'alice'),
          ),
          billNotificationClientProvider.overrideWithValue(client),
          billReminderClockProvider.overrideWithValue(() => calendarNow),
          recurringBillsProvider.overrideWith((ref) => bills.stream),
          cloudStatusProvider.overrideWith((ref) => statuses.stream),
        ],
      );
      final sub = container.listen(billReminderProvider, (_, _) {});
      Future<void> settle() async {
        await Future<void>.delayed(Duration.zero);
        await container.pump();
        await Future<void>.delayed(Duration.zero);
      }

      addTearDown(() async {
        sub.close();
        container.dispose();
        client.dispose();
        await bills.close();
        await statuses.close();
      });
      bills.add([calendarBill(due: DateTime(2026, 12, 16))]);
      statuses.add(
        const CloudStatus(loading: false, fromCache: true, dataset: 'main'),
      );
      await settle();
      final controller = container.read(billReminderProvider.notifier);
      expect(client.permissionRequests, 0);
      await controller.setEnabled(true);
      expect(client.replacements, isEmpty);
      statuses.add(const CloudStatus(loading: false, dataset: 'main'));
      await settle();
      expect(client.replacements.last.map((p) => p.day), [
        '2026-12-15',
        '2026-12-16',
      ]);
      bills.add([calendarBill(active: false)]);
      await settle();
      expect(client.replacements.last, isEmpty);
      container.read(sessionClosingProvider.notifier).setClosing(true);
      await settle();
      expect(client.activeAccount, isNull);
    },
  );
}
