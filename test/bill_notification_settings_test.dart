import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/app/providers/auth_providers.dart';
import 'package:dompet_sheva/app/providers/bill_reminder_providers.dart';
import 'package:dompet_sheva/app/providers/planning_providers.dart';
import 'package:dompet_sheva/app/theme/app_theme.dart';
import 'package:dompet_sheva/data/auth/auth_repository.dart';
import 'package:dompet_sheva/data/notifications/bill_notification_client.dart';
import 'package:dompet_sheva/data/notifications/bill_reminder_batch.dart';
import 'package:dompet_sheva/data/store/cloud_finance_store.dart';
import 'package:dompet_sheva/features/planning/planning_page.dart';
import 'package:dompet_sheva/features/planning/web_bill_reminder_host.dart';
import 'package:dompet_sheva/features/planning/widgets/bill_notification_settings_card.dart';

import 'helpers/fake_bill_notification_client.dart';
import 'helpers/financial_calendar_fixture.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('one compact switch controls both off and on states', (
    tester,
  ) async {
    final client = await _open(tester);
    expect(client.permissionRequests, 0);
    expect(find.byType(Text), findsOneWidget);
    expect(find.text('Notifikasi tagihan'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    final offSize = tester.getSize(find.byType(BillNotificationSettingsCard));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(client.permissionRequests, 1);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(tester.getSize(find.byType(BillNotificationSettingsCard)), offSize);
    expect(find.byType(Text), findsOneWidget);
    expect(client.delivered.single.phase, 'today');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(client.enabled, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(tester.getSize(find.byType(BillNotificationSettingsCard)), offSize);
    expect(client.permissionRequests, 1);
  });

  testWidgets('denied permission provides recovery instructions and refresh', (
    tester,
  ) async {
    final client = FakeBillNotificationClient()
      ..requestedPermission = BillNotificationPermission.denied;
    await _open(tester, client: client);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('pengaturan browser atau perangkat'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    client.currentPermission = BillNotificationPermission.granted;
    await tester.tap(find.text('Periksa izin'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(client.permissionRequests, 1);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(client.enabled, isTrue);
  });

  testWidgets('iOS installation requirement never opens a permission prompt', (
    tester,
  ) async {
    final client = FakeBillNotificationClient()
      ..currentPermission = BillNotificationPermission.install;
    await _open(tester, client: client);
    expect(find.byType(Text), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('Layar Utama'), findsOneWidget);
    expect(client.enabled, isFalse);
    expect(client.permissionRequests, 0);
  });

  testWidgets(
    'first visit recommends optional reminders without requesting permission',
    (tester) async {
      final client = await _open(tester, host: true);
      expect(find.text('Aktifkan pengingat?'), findsOneWidget);
      expect(find.textContaining('Opsional'), findsOneWidget);
      expect(client.permissionRequests, 0);
      expect(client.preparations, 0);
      await tester.tap(find.text('Nanti saja'));
      await tester.pumpAndSettle();
      expect(client.enabled, isFalse);
      expect(client.permissionRequests, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, host: true, client: client);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(client.enabled, isTrue);
    },
  );

  testWidgets(
    'recommendation enables reminders directly from the explicit tap',
    (tester) async {
      final client = await _open(tester, host: true);
      await tester.tap(find.text('Aktifkan'));
      expect(client.permissionRequests, 1);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(client.enabled, isTrue);
      expect(client.delivered.single.phase, 'today');
    },
  );

  testWidgets(
    'dismissed recommendation stays optional and is not shown again',
    (tester) async {
      final client = await _open(tester, host: true);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(client.enabled, isFalse);
      expect(client.permissionRequests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, host: true, client: client);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'already enabled reminders do not show a startup recommendation',
    (tester) async {
      final client = FakeBillNotificationClient()
        ..enabled = true
        ..currentPermission = BillNotificationPermission.granted;
      await _open(tester, host: true, client: client);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(client.permissionRequests, 0);
    },
  );

  testWidgets('Android and signed-out sessions never show the recommendation', (
    tester,
  ) async {
    for (final (isWeb, account) in [
      (false, const AppAccount(uid: 'alice')),
      (true, null),
    ]) {
      final client = await _open(
        tester,
        host: true,
        isWeb: isWeb,
        account: account,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(client.activations, 0);
      expect(client.permissionRequests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('notification clicks open bills only for the active account', (
    tester,
  ) async {
    final client = await _open(tester, host: true);
    await tester.tap(find.text('Nanti saja'));
    await tester.pumpAndSettle();
    client.opens.add(billReminderAccountKey('bob'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanningPage), findsNothing);
    client.opens.add(billReminderAccountKey('alice'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanningPage), findsOneWidget);
    expect(find.text('Perencanaan'), findsOneWidget);
  });

  testWidgets('resuming the app rechecks the current reminder date', (
    tester,
  ) async {
    var now = calendarNow;
    final client = await _open(tester, host: true, clock: () => now);
    await tester.tap(find.text('Aktifkan'));
    await tester.pumpAndSettle();
    expect(client.delivered.single.phase, 'today');
    now = DateTime(2026, 11, 17, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    // The old next-unpaid schedule is now overdue and should not be re-sent.
    expect(client.delivered, hasLength(1));
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'notification controls fit narrow ${theme.brightness.name} screens',
      (tester) async {
        await _open(tester, theme: theme, width: 320, scale: 1.3);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'optional recommendation fits narrow ${theme.brightness.name} screens',
      (tester) async {
        await _open(tester, host: true, theme: theme, width: 320, scale: 1.3);
        expect(find.text('Aktifkan pengingat?'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Nanti saja'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<FakeBillNotificationClient> _open(
  WidgetTester tester, {
  FakeBillNotificationClient? client,
  bool host = false,
  bool isWeb = true,
  AppAccount? account = const AppAccount(uid: 'alice'),
  DateTime Function()? clock,
  ThemeData? theme,
  double width = 420,
  double scale = 1,
}) async {
  final notifications = client ?? FakeBillNotificationClient();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1100);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(notifications.dispose);
  const card = BillNotificationSettingsCard();
  final content = ListView(
    padding: const EdgeInsets.all(20),
    children: const [card],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        webPlatformProvider.overrideWithValue(isWeb),
        currentAccountProvider.overrideWithValue(account),
        billNotificationClientProvider.overrideWithValue(notifications),
        billReminderClockProvider.overrideWithValue(clock ?? () => calendarNow),
        recurringBillsProvider.overrideWith(
          (ref) => Stream.value([calendarBill()]),
        ),
        cloudStatusProvider.overrideWith(
          (ref) =>
              Stream.value(const CloudStatus(loading: false, dataset: 'main')),
        ),
        walletBalancesProvider.overrideWith((ref) => Stream.value([])),
        categoriesProvider.overrideWith((ref) => Stream.value([])),
        appSettingsProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: host ? WebBillReminderHost(child: content) : content,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifications;
}
