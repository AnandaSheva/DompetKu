import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/app/providers/auth_providers.dart';
import 'package:dompet_sheva/app/providers/bill_reminder_providers.dart';
import 'package:dompet_sheva/app/providers/planning_providers.dart';
import 'package:dompet_sheva/data/auth/auth_repository.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/notifications/bill_notification_client.dart';
import 'package:dompet_sheva/data/notifications/bill_reminder_batch.dart';
import 'package:dompet_sheva/data/store/cloud_finance_store.dart';

import 'helpers/fake_bill_notification_client.dart';
import 'helpers/financial_calendar_fixture.dart';

void main() {
  test(
    'permission is requested only on explicit enable, before worker setup',
    () async {
      final fixture = await _Fixture.open();
      expect(fixture.client.permissionRequests, 0);
      expect(fixture.client.preparations, 0);
      expect(fixture.client.delivered, isEmpty);
      final enabling = fixture.controller.setEnabled(true);
      expect(fixture.client.permissionRequests, 1);
      expect(fixture.client.preparations, 0);
      await enabling;
      expect(fixture.state.enabled, isTrue);
      expect(fixture.client.delivered.single.phase, 'today');
    },
  );

  for (final permission in [
    BillNotificationPermission.denied,
    BillNotificationPermission.prompt,
  ]) {
    test(
      'refused or dismissed permission leaves reminders disabled: $permission',
      () async {
        final fixture = await _Fixture.open();
        fixture.client.requestedPermission = permission;
        await fixture.controller.setEnabled(true);
        expect(fixture.state.enabled, isFalse);
        expect(fixture.state.permission, permission);
        expect(fixture.client.preparations, 0);
        expect(fixture.client.delivered, isEmpty);
      },
    );
  }

  test('failed worker setup is reported without enabling reminders', () async {
    final fixture = await _Fixture.open();
    fixture.client.failPreparation = true;
    await fixture.controller.setEnabled(true);
    expect(fixture.state.enabled, isFalse);
    expect(fixture.state.busy, isFalse);
    expect(fixture.state.error, isNotNull);
    expect(fixture.client.enabled, isFalse);
  });

  test(
    'Android and absent auth never activate notification clients or data streams',
    () async {
      for (final (isWeb, account) in [
        (false, const AppAccount(uid: 'alice')),
        (true, null),
      ]) {
        final client = FakeBillNotificationClient();
        final container = ProviderContainer(
          overrides: [
            webPlatformProvider.overrideWithValue(isWeb),
            currentAccountProvider.overrideWithValue(account),
            billNotificationClientProvider.overrideWithValue(client),
            recurringBillsProvider.overrideWith(
              (ref) => throw StateError('Unexpected data listener'),
            ),
          ],
        );
        final subscription = container.listen(billReminderProvider, (_, _) {});
        expect(container.read(billReminderProvider).enabled, isFalse);
        await container.read(billReminderProvider.notifier).setEnabled(true);
        expect(client.activations, 0);
        expect(client.permissionRequests, 0);
        subscription.close();
        container.dispose();
        client.dispose();
      }
    },
  );

  test(
    'cached or pending account data is held until synchronization completes',
    () async {
      final fixture = await _Fixture.open(
        cloud: const CloudStatus(
          loading: false,
          fromCache: true,
          dataset: 'main',
        ),
      );
      await fixture.controller.setEnabled(true);
      expect(fixture.client.delivered, isEmpty);
      fixture.cloud.add(
        const CloudStatus(loading: false, pending: true, dataset: 'main'),
      );
      await fixture.settle();
      expect(fixture.client.delivered, isEmpty);
      fixture.cloud.add(const CloudStatus(loading: false, dataset: 'main'));
      await fixture.settle();
      expect(fixture.client.delivered.single.phase, 'today');
    },
  );

  test('advancing a paid bill cancels a delivery still in progress', () async {
    final fixture = await _Fixture.open();
    fixture.client.holdDelivery = Completer<void>();
    final enabling = fixture.controller.setEnabled(true);
    await fixture.settle();
    expect(fixture.client.attempted, hasLength(1));
    fixture.bills.add([calendarBill(due: DateTime(2026, 12, 16))]);
    await fixture.settle();
    fixture.client.holdDelivery!.complete();
    await enabling;
    expect(fixture.client.delivered, isEmpty);
  });

  test('disable cancels pending reminders and later checks', () async {
    final fixture = await _Fixture.open();
    fixture.client.holdDelivery = Completer<void>();
    final enabling = fixture.controller.setEnabled(true);
    await fixture.settle();
    await fixture.controller.setEnabled(false);
    fixture.client.holdDelivery!.complete();
    await enabling;
    await fixture.controller.check();
    expect(fixture.client.delivered, isEmpty);
    expect(fixture.state.enabled, isFalse);
  });

  test(
    'logout prevents pending permission/worker work from enabling reminders',
    () async {
      final fixture = await _Fixture.open();
      fixture.client.holdPreparation = Completer<void>();
      final enabling = fixture.controller.setEnabled(true);
      await fixture.settle();
      fixture.container.read(sessionClosingProvider.notifier).setClosing(true);
      fixture.client.holdPreparation!.complete();
      await enabling;
      expect(fixture.client.enabled, isFalse);
      expect(fixture.client.activeAccount, isNull);
      expect(fixture.client.delivered, isEmpty);
    },
  );

  test(
    'an account change rejects results from an older permission request',
    () async {
      final fixture = await _Fixture.open();
      fixture.client.holdPreparation = Completer<void>();
      final enabling = fixture.controller.setEnabled(true);
      await fixture.settle();
      fixture.container.updateOverrides([
        ...fixture.overrides,
        currentAccountProvider.overrideWithValue(const AppAccount(uid: 'bob')),
      ]);
      await fixture.settle();
      fixture.client.holdPreparation!.complete();
      await enabling;
      expect(fixture.client.activeAccount, billReminderAccountKey('bob'));
      expect(fixture.state.enabled, isFalse);
      expect(fixture.client.delivered, isEmpty);
    },
  );

  test('notification navigation matches the current account only', () async {
    final fixture = await _Fixture.open();
    fixture.client.opens.add(billReminderAccountKey('bob'));
    await fixture.settle();
    expect(fixture.state.openRequest, 0);
    fixture.client.opens.add(billReminderAccountKey('alice'));
    await fixture.settle();
    expect(fixture.state.openRequest, 1);
  });

  test(
    'resuming on the due day switches H-1 to H and rechecks revoked permission',
    () async {
      final fixture = await _Fixture.open(
        bills: [calendarBill(due: DateTime(2026, 11, 17))],
      );
      await fixture.controller.setEnabled(true);
      expect(fixture.client.delivered.single.phase, 'tomorrow');
      fixture.now = DateTime(2026, 11, 17, 8);
      await fixture.controller.refresh();
      expect(fixture.client.delivered.last.phase, 'today');
      fixture.client.currentPermission = BillNotificationPermission.denied;
      await fixture.controller.refresh();
      expect(fixture.state.permission, BillNotificationPermission.denied);
      expect(fixture.client.delivered, hasLength(2));
    },
  );
}

class _Fixture {
  final client = FakeBillNotificationClient();
  final bills = StreamController<List<RecurringBillEntry>>.broadcast();
  final cloud = StreamController<CloudStatus>.broadcast();
  late ProviderContainer container;
  DateTime now = calendarNow;
  BillReminderController get controller =>
      container.read(billReminderProvider.notifier);
  BillReminderState get state => container.read(billReminderProvider);
  late final overrides = [
    webPlatformProvider.overrideWithValue(true),
    billNotificationClientProvider.overrideWithValue(client),
    billReminderClockProvider.overrideWithValue(() => now),
    recurringBillsProvider.overrideWith((ref) => bills.stream),
    cloudStatusProvider.overrideWith((ref) => cloud.stream),
  ];

  static Future<_Fixture> open({
    CloudStatus cloud = const CloudStatus(loading: false, dataset: 'main'),
    List<RecurringBillEntry>? bills,
  }) async {
    final fixture = _Fixture();
    fixture.container = ProviderContainer(
      overrides: [
        ...fixture.overrides,
        currentAccountProvider.overrideWithValue(
          const AppAccount(uid: 'alice'),
        ),
      ],
    );
    fixture.container.listen(billReminderProvider, (_, _) {});
    fixture.bills.add(bills ?? [calendarBill()]);
    fixture.cloud.add(cloud);
    addTearDown(() async {
      fixture.container.dispose();
      fixture.client.dispose();
      await fixture.bills.close();
      await fixture.cloud.close();
    });
    await fixture.settle();
    return fixture;
  }

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
  }
}
