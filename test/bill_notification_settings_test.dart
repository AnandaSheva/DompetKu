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

  testWidgets('permission is opt-in and reminders work without a test button', (
    tester,
  ) async {
    final client = await _open(tester);
    expect(client.permissionRequests, 0);
    expect(
      find.textContaining('Tidak berjalan saat aplikasi ditutup'),
      findsOneWidget,
    );
    await tester.tap(find.text('Aktifkan notifikasi'));
    await tester.pumpAndSettle();
    expect(client.permissionRequests, 1);
    expect(find.text('Aktif untuk akun ini di browser ini.'), findsOneWidget);
    expect(find.text('Kirim notifikasi uji'), findsNothing);
    expect(client.delivered.single.phase, 'today');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(client.enabled, isFalse);
    expect(find.text('Aktifkan notifikasi'), findsOneWidget);
  });

  testWidgets('denied permission provides recovery instructions and refresh', (
    tester,
  ) async {
    final client = FakeBillNotificationClient()
      ..requestedPermission = BillNotificationPermission.denied;
    await _open(tester, client: client);
    await tester.tap(find.text('Aktifkan notifikasi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Izin diblokir'), findsOneWidget);
    expect(find.text('Kirim notifikasi uji'), findsNothing);
    client.currentPermission = BillNotificationPermission.granted;
    await tester.tap(find.text('Periksa izin'));
    await tester.pumpAndSettle();
    expect(find.text('Aktifkan notifikasi'), findsOneWidget);
    expect(client.permissionRequests, 1);
  });

  testWidgets('iOS installation requirement never opens a permission prompt', (
    tester,
  ) async {
    final client = FakeBillNotificationClient()
      ..currentPermission = BillNotificationPermission.install;
    await _open(tester, client: client);
    expect(find.textContaining('Layar Utama'), findsOneWidget);
    expect(find.text('Aktifkan notifikasi'), findsNothing);
    expect(client.permissionRequests, 0);
  });

  testWidgets('notification clicks open bills only for the active account', (
    tester,
  ) async {
    final client = await _open(tester, host: true);
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
    await tester.tap(find.text('Aktifkan notifikasi'));
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
        await tester.tap(find.text('Aktifkan notifikasi'));
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
        webPlatformProvider.overrideWithValue(true),
        currentAccountProvider.overrideWithValue(
          const AppAccount(uid: 'alice'),
        ),
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
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: host ? WebBillReminderHost(child: content) : content,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifications;
}
