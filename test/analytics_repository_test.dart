import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/core/enums/analytics_period.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/analytics_repository.dart';
import 'package:dompet_sheva/data/repositories/bootstrap_repository.dart';
import 'package:dompet_sheva/data/repositories/settings_repository.dart';

void main() {
  late AppDatabase database;
  late AnalyticsRepository repository;
  late DateTime now;
  late List<WalletEntry> wallets;
  late int incomeCategory;
  late int expenseCategory;

  setUp(() async {
    now = DateTime(2026, 11, 14, 12);
    database = AppDatabase(NativeDatabase.memory());
    repository = AnalyticsRepository(database, clock: () => now);
    await BootstrapRepository(database).ensureSeeded();
    wallets = await database.walletsDao.getAll();
    incomeCategory = (await database.categoriesDao.getByType(
      'income',
    )).first.id;
    expenseCategory = (await database.categoriesDao.getByType(
      'expense',
    )).first.id;
  });
  tearDown(() => database.close());

  Future<void> add(String type, int amount, DateTime date) async {
    await database.transactionsDao.add(
      TransactionEntriesCompanion.insert(
        type: type,
        amount: amount,
        categoryId: Value(
          type == 'transfer'
              ? null
              : type == 'income'
              ? incomeCategory
              : expenseCategory,
        ),
        walletId: wallets.first.id,
        transferWalletId: Value(type == 'transfer' ? wallets.last.id : null),
        date: date,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  for (final period in AnalyticsPeriod.values) {
    test('${period.name} reconciles charts and totals through today', () async {
      await add('income', 600000, DateTime(2026, 11, 1));
      await add('expense', 200000, DateTime(2026, 11, 14, 23, 59));
      await add('transfer', 900000, now);
      await add('expense', 800000, DateTime(2026, 11, 15));
      await add('income', 700000, DateTime(2027, 1, 1));

      final summary = await repository.getSummary(period);
      expect(summary.totalIncome, 600000);
      expect(summary.totalExpense, 200000);
      expect(summary.netCashflow, 400000);
      expect(summary.incomeByCategory.single.amount, summary.totalIncome);
      expect(summary.expenseByCategory.single.amount, summary.totalExpense);
      expect(
        summary.weeklyExpense.fold<int>(0, (sum, row) => sum + row.amount),
        200000,
      );
      expect(summary.dailyCashflow.last.endDate, DateTime(2026, 11, 15));
    });
  }

  test('all-time history includes records older than twelve months', () async {
    await add('transfer', 900000, DateTime(2020, 1, 1));
    await add('income', 1000000, DateTime(2024, 1, 10));
    await add('expense', 250000, DateTime(2025, 5, 1));
    await add('income', 500000, now);

    final summary = await repository.getSummary(AnalyticsPeriod.allTime);
    expect(summary.dailyCashflow, hasLength(35));
    expect(summary.dailyCashflow.first.date, DateTime(2024, 1));
    expect(summary.dailyCashflow.first.income, 1000000);
    expect(summary.totalIncome, 1500000);
    expect(summary.totalExpense, 250000);
    expect(summary.netCashflow, 1250000);
  });

  test(
    'custom three-month cycles have exact inclusive and exclusive boundaries',
    () async {
      await SettingsRepository(database).setMonthlyResetDay(20);
      await add('income', 999999, DateTime(2026, 8, 19, 23, 59));
      await add('income', 1000000, DateTime(2026, 8, 20));
      await add('expense', 200000, DateTime(2026, 9, 19, 23, 59));
      await add('expense', 300000, DateTime(2026, 9, 20));
      await add('income', 500000, DateTime(2026, 10, 20));
      await add('expense', 100000, now);
      await add('expense', 888888, DateTime(2026, 11, 20));

      final summary = await repository.getSummary(AnalyticsPeriod.last3Months);
      final points = summary.dailyCashflow;
      expect(points.map((row) => row.date), [
        DateTime(2026, 8, 20),
        DateTime(2026, 9, 20),
        DateTime(2026, 10, 20),
      ]);
      expect(points.map((row) => row.income), [1000000, 0, 500000]);
      expect(points.map((row) => row.expense), [200000, 300000, 100000]);
      expect(points.first.endDate, DateTime(2026, 9, 20));
      expect(points.last.endDate, DateTime(2026, 11, 15));
      expect(summary.netCashflow, 900000);
    },
  );

  test(
    'daily series includes zero days and keeps balanced activity visible',
    () async {
      await add('income', 500000, DateTime(2026, 11, 2));
      await add('expense', 500000, DateTime(2026, 11, 2));
      final summary = await repository.getSummary(AnalyticsPeriod.currentMonth);

      expect(summary.dailyCashflow, hasLength(14));
      expect(summary.dailyCashflow.first.income, 0);
      expect(summary.dailyCashflow[1].netCashflow, 0);
      expect(summary.totalIncome, 500000);
      expect(summary.totalExpense, 500000);
      expect(summary.isEmpty, false);
    },
  );

  test('short-month reset produces a real single-day point', () async {
    now = DateTime(2026, 2, 28, 12);
    await SettingsRepository(database).setMonthlyResetDay(31);
    await add('income', 999999, DateTime(2026, 2, 27));
    await add('expense', 100000, now);
    await add('income', 999999, DateTime(2026, 3, 1));

    final summary = await repository.getSummary(AnalyticsPeriod.currentMonth);
    expect(summary.dailyCashflow.single.date, DateTime(2026, 2, 28));
    expect(summary.dailyCashflow.single.endDate, DateTime(2026, 3, 1));
    expect(summary.totalIncome, 0);
    expect(summary.netCashflow, -100000);
  });

  test(
    'year-to-date does not include the previous year or future dates',
    () async {
      now = DateTime(2026, 1, 9, 12);
      await SettingsRepository(database).setMonthlyResetDay(20);
      await add('income', 999999, DateTime(2025, 12, 31));
      await add('income', 400000, DateTime(2026, 1, 1));
      await add('expense', 100000, now);
      await add('expense', 999999, DateTime(2026, 1, 10));

      final summary = await repository.getSummary(AnalyticsPeriod.yearToDate);
      expect(summary.dailyCashflow.single.date, DateTime(2026, 1, 1));
      expect(summary.dailyCashflow.single.endDate, DateTime(2026, 1, 10));
      expect(summary.netCashflow, 300000);
    },
  );

  test(
    'transfer-only and future-only records do not fabricate cashflow',
    () async {
      await add('transfer', 900000, DateTime(2024, 1, 1));
      await add('income', 900000, DateTime(2026, 12, 1));
      final summary = await repository.getSummary(AnalyticsPeriod.allTime);

      expect(summary.isEmpty, true);
      expect(summary.dailyCashflow, isEmpty);
      expect(summary.netCashflow, 0);
    },
  );

  test(
    'live cashflow updates when transactions and the reset day change',
    () async {
      await add('income', 1000000, DateTime(2026, 10, 31));
      final updates = StreamIterator(
        repository.watchSummary(AnalyticsPeriod.currentMonth),
      );
      addTearDown(updates.cancel);
      expect(await updates.moveNext(), true);
      expect(updates.current.netCashflow, 0);

      await add('expense', 200000, now);
      expect(await updates.moveNext(), true);
      expect(updates.current.netCashflow, -200000);

      await SettingsRepository(database).setMonthlyResetDay(20);
      expect(await updates.moveNext(), true);
      expect(updates.current.totalIncome, 1000000);
      expect(updates.current.netCashflow, 800000);
    },
  );
}
