import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/app/providers/planning_providers.dart';
import 'package:dompet_sheva/app/theme/app_theme.dart';
import 'package:dompet_sheva/core/formatters/currency_formatter.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/app_models.dart';
import 'package:dompet_sheva/features/analytics/widgets/financial_calendar_card.dart';
import 'package:dompet_sheva/features/planning/planning_page.dart';
import 'package:dompet_sheva/features/transactions/widgets/transaction_tile.dart';

import 'helpers/financial_calendar_fixture.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
    'starts on today and selects actual daily income, expense and bills',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Senin, 16 November 2026'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendar-Pemasukan')))
            .data,
        CurrencyFormatter.rupiah(1000000),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendar-Pengeluaran')))
            .data,
        CurrencyFormatter.rupiah(75000),
      );
      expect(find.text('Internet rumah'), findsOneWidget);
      expect(find.text('Jatuh tempo hari ini'), findsOneWidget);
      expect(find.byType(TransactionTile), findsNWidgets(3));
      expect(
        find.bySemanticsLabel(
          RegExp('Senin, 16 November 2026, hari ini, 3 transaksi, 1 tagihan'),
        ),
        findsOneWidget,
      );

      await _selectDay(tester, '2026-11-17');
      expect(find.text('Selasa, 17 November 2026'), findsOneWidget);
      expect(
        find.text('Belum ada transaksi atau tagihan pada tanggal ini.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendar-Pemasukan')))
            .data,
        CurrencyFormatter.rupiah(0),
      );
      expect(find.byType(TransactionTile), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'month navigation shows projected bills and today resets the date',
    (tester) async {
      await _open(tester);
      await tester.tap(find.byTooltip('Bulan berikutnya'));
      await tester.pumpAndSettle();
      expect(find.text('Desember 2026'), findsOneWidget);
      expect(find.text('Perkiraan jadwal berikutnya'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendar-Pengeluaran')))
            .data,
        CurrencyFormatter.rupiah(0),
      );
      await tester.tap(find.text('Hari ini'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Senin, 16 November 2026'), findsOneWidget);
      expect(find.text('Jatuh tempo hari ini'), findsOneWidget);
    },
  );

  testWidgets(
    'a short month selects its last valid day with a real leap-year grid',
    (tester) async {
      await _open(tester, clock: () => DateTime(2024, 1, 31, 12));
      await tester.tap(find.byTooltip('Bulan berikutnya'));
      await tester.pumpAndSettle();
      expect(find.text('Februari 2024'), findsOneWidget);
      expect(find.text('Kamis, 29 Februari 2024'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('calendar-day-2024-02-29')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('calendar-day-2024-02-30')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'month picker chooses a year and month and cancellation preserves the view',
    (tester) async {
      await _open(tester);
      await tester.tap(find.text('November 2026'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih bulan'), findsOneWidget);
      await tester.tap(find.byTooltip('Tahun berikutnya'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feb'));
      await tester.pumpAndSettle();
      expect(find.text('Februari 2027'), findsOneWidget);
      expect(find.text('Selasa, 16 Februari 2027'), findsOneWidget);
      await tester.tap(find.text('Februari 2027'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tahun sebelumnya'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Februari 2027'), findsOneWidget);
    },
  );

  testWidgets(
    'reflects transaction and bill changes without changing selected date',
    (tester) async {
      final transactions = StreamController<List<TransactionDetail>>();
      final bills = StreamController<List<RecurringBillEntry>>();
      addTearDown(transactions.close);
      addTearDown(bills.close);
      await _open(
        tester,
        transactions: transactions.stream,
        bills: bills.stream,
      );
      expect(find.text('Memuat transaksi dan tagihan...'), findsOneWidget);
      transactions.add([]);
      bills.add([calendarBill()]);
      await tester.pumpAndSettle();
      expect(find.text('Internet rumah'), findsOneWidget);
      transactions.add([
        calendarTransaction(
          type: 'expense',
          amount: 250000,
          date: calendarNow,
          note: 'Pembayaran internet',
        ),
      ]);
      bills.add([calendarBill(due: DateTime(2026, 12, 16))]);
      await tester.pumpAndSettle();
      expect(find.text('Internet rumah'), findsNothing);
      expect(find.text('Senin, 16 November 2026'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendar-Pengeluaran')))
            .data,
        CurrencyFormatter.rupiah(250000),
      );
      expect(find.textContaining('Pembayaran internet'), findsOneWidget);
    },
  );

  testWidgets(
    'reports a stream failure and allows a retry without showing zero totals',
    (tester) async {
      var requests = 0;
      await _open(
        tester,
        transactionSource: () {
          requests++;
          return requests == 1
              ? Stream.error(StateError('Unavailable'))
              : Stream.value(_transactions);
        },
      );
      expect(find.text('Data kalender belum bisa dimuat.'), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-Pemasukan')), findsNothing);
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('Data kalender belum bisa dimuat.'), findsNothing);
      expect(find.byKey(const ValueKey('calendar-Pemasukan')), findsOneWidget);
    },
  );

  testWidgets(
    'hide balance masks daily totals, transactions and scheduled amounts',
    (tester) async {
      await _open(tester, hidden: true);
      expect(find.textContaining('1.000.000'), findsNothing);
      expect(find.textContaining('250.000'), findsNothing);
      expect(find.textContaining('75.000'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendar-Pemasukan')))
            .data,
        CurrencyFormatter.rupiah(0, hidden: true),
      );
      expect(find.text('Internet rumah'), findsOneWidget);
    },
  );

  testWidgets(
    'midnight and resume refresh today while preserving a manually selected date',
    (tester) async {
      var now = DateTime(2026, 11, 30, 23, 59, 59);
      await _open(tester, clock: () => now);
      now = DateTime(2026, 12, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Desember 2026'), findsOneWidget);
      expect(find.text('Selasa, 1 Desember 2026'), findsOneWidget);
      await _selectDay(tester, '2026-12-03');
      now = DateTime(2026, 12, 2, 8);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Kamis, 3 Desember 2026'), findsOneWidget);
      await tester.tap(find.text('Hari ini'));
      await tester.pumpAndSettle();
      expect(find.text('Rabu, 2 Desember 2026'), findsOneWidget);
    },
  );

  testWidgets('opens the existing bill management page', (tester) async {
    await _open(tester);
    await tester.ensureVisible(find.text('Kelola tagihan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kelola tagihan'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanningPage), findsOneWidget);
    expect(find.text('Perencanaan'), findsOneWidget);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'fits a narrow ${theme.brightness.name} screen and large text',
      (tester) async {
        await _open(
          tester,
          theme: theme,
          width: 320,
          textScale: 1.3,
          transactions: Stream.value([
            calendarTransaction(
              type: 'income',
              amount: 9007199254740991,
              date: calendarNow,
            ),
            calendarTransaction(
              id: 2,
              type: 'expense',
              amount: 9007199254740991,
              date: calendarNow,
            ),
          ]),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('November 2026'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        await _selectDay(tester, '2026-11-30');
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final _transactions = [
  calendarTransaction(
    type: 'income',
    amount: 1000000,
    date: DateTime(2026, 11, 16, 9),
    note: 'Gaji',
  ),
  calendarTransaction(
    id: 2,
    type: 'expense',
    amount: 75000,
    date: DateTime(2026, 11, 16, 10),
    note: 'Belanja harian',
  ),
  calendarTransaction(
    id: 3,
    type: 'transfer',
    amount: 500000,
    date: DateTime(2026, 11, 16, 11),
  ),
];

Future<void> _selectDay(WidgetTester tester, String date) async {
  final cell = find.byKey(ValueKey('calendar-day-$date'));
  await tester.ensureVisible(cell);
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester, {
  DateTime Function()? clock,
  Stream<List<TransactionDetail>>? transactions,
  Stream<List<TransactionDetail>> Function()? transactionSource,
  Stream<List<RecurringBillEntry>>? bills,
  bool hidden = false,
  ThemeData? theme,
  double width = 420,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1100);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionDetailsProvider.overrideWith(
          (ref) =>
              transactionSource?.call() ??
              transactions ??
              Stream.value(_transactions),
        ),
        recurringBillsProvider.overrideWith(
          (ref) => bills ?? Stream.value([calendarBill()]),
        ),
        walletBalancesProvider.overrideWith(
          (ref) => Stream.value([
            WalletBalance(wallet: calendarWallet, balance: 1000000),
          ]),
        ),
        categoriesProvider.overrideWith((ref) => Stream.value([])),
        appSettingsProvider.overrideWith(
          (ref) => Stream.value(
            AppSettingEntry(
              id: 1,
              currency: 'IDR',
              themeMode: 'system',
              hideBalance: hidden,
              onboardingCompleted: true,
              monthlyResetDay: 20,
              createdAt: calendarNow,
              updatedAt: calendarNow,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                FinancialCalendarCard(clock: clock ?? () => calendarNow),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
