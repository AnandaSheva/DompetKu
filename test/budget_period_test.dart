import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/core/enums/analytics_period.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/bootstrap_repository.dart';
import 'package:dompet_sheva/data/repositories/budget_repository.dart';
import 'package:dompet_sheva/data/repositories/settings_repository.dart';

const _months = [
  '2025-11',
  '2025-12',
  '2026-01',
  '2026-02',
  '2026-08',
  '2026-09',
  '2026-10',
  '2026-11',
  '2026-12',
];

void main() {
  late AppDatabase database;
  late BudgetRepository repository;
  late DateTime now;

  setUp(() async {
    now = DateTime(2026, 11, 14, 12);
    database = AppDatabase(NativeDatabase.memory());
    repository = BudgetRepository(database, clock: () => now);
    await BootstrapRepository(database).ensureSeeded();
    for (final month in _months) {
      await repository.save(month: month, limitAmount: 100000);
    }
    final category = (await database.categoriesDao.getByType('expense')).first;
    final wallets = await database.walletsDao.getAll();
    for (final (date, amount) in [
      (DateTime(2026, 10, 31), 10000),
      (DateTime(2026, 11, 1), 20000),
      (DateTime(2026, 11, 14), 30000),
      (DateTime(2026, 12, 1), 40000),
    ]) {
      await database.transactionsDao.add(
        TransactionEntriesCompanion.insert(
          type: 'expense',
          amount: amount,
          categoryId: Value(category.id),
          walletId: wallets.first.id,
          date: date,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await database.transactionsDao.add(
      TransactionEntriesCompanion.insert(
        type: 'income',
        amount: 90000,
        categoryId: Value(
          (await database.categoriesDao.getByType('income')).first.id,
        ),
        walletId: wallets.first.id,
        date: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.transactionsDao.add(
      TransactionEntriesCompanion.insert(
        type: 'transfer',
        amount: 5000,
        walletId: wallets.first.id,
        transferWalletId: Value(wallets.last.id),
        date: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });
  tearDown(() => database.close());

  test(
    'current month excludes previous and future budgets and expenses',
    () async {
      final items = await repository.getProgress(
        period: AnalyticsPeriod.currentMonth,
      );

      expect(items.single.budget.month, '2026-11');
      expect(items.single.spent, 50000);
      expect(await database.budgetsDao.getAll(), hasLength(_months.length));
    },
  );

  for (final (period, months) in [
    (AnalyticsPeriod.last3Months, ['2026-09', '2026-10', '2026-11']),
    (
      AnalyticsPeriod.yearToDate,
      ['2026-01', '2026-02', '2026-08', '2026-09', '2026-10', '2026-11'],
    ),
    (AnalyticsPeriod.allTime, _months),
  ]) {
    test('${period.name} shows the matching budget months', () async {
      final items = await repository.getProgress(period: period);
      expect(items.map((item) => item.budget.month), unorderedEquals(months));
    });
  }

  test('unfiltered repository access preserves all budgets', () async {
    final items = await repository.getProgress();
    expect(items.map((item) => item.budget.month), unorderedEquals(_months));
  });

  test(
    'current-month stream follows changes to the monthly reset day',
    () async {
      final updates = StreamIterator(
        repository.watchProgress(period: AnalyticsPeriod.currentMonth),
      );
      addTearDown(updates.cancel);

      expect(await updates.moveNext(), true);
      expect(updates.current.single.budget.month, '2026-11');
      expect(updates.current.single.spent, 50000);

      await SettingsRepository(database).setMonthlyResetDay(20);
      expect(await updates.moveNext(), true);
      expect(updates.current.single.budget.month, '2026-10');
      expect(updates.current.single.spent, 60000);
    },
  );

  test('three-month filter crosses the year boundary correctly', () async {
    now = DateTime(2026, 1, 14);
    final items = await repository.getProgress(
      period: AnalyticsPeriod.last3Months,
    );

    expect(
      items.map((item) => item.budget.month),
      unorderedEquals(['2025-11', '2025-12', '2026-01']),
    );
  });

  test('current month clamps the reset day in a shorter month', () async {
    now = DateTime(2026, 2, 28, 12);
    await SettingsRepository(database).setMonthlyResetDay(31);
    final items = await repository.getProgress(
      period: AnalyticsPeriod.currentMonth,
    );

    expect(items.single.budget.month, '2026-02');
  });

  test(
    'year filter includes the cycle overlapping the start of the year',
    () async {
      now = DateTime(2026, 1, 9);
      await SettingsRepository(database).setMonthlyResetDay(20);
      final items = await repository.getProgress(
        period: AnalyticsPeriod.yearToDate,
      );

      expect(items.single.budget.month, '2025-12');
    },
  );

  test(
    'a month without budgets returns an empty result without deleting history',
    () async {
      now = DateTime(2027, 1, 14);
      final items = await repository.getProgress(
        period: AnalyticsPeriod.currentMonth,
      );

      expect(items, isEmpty);
      expect(await database.budgetsDao.getAll(), hasLength(_months.length));
    },
  );
}
