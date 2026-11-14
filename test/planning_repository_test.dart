import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/bootstrap_repository.dart';
import 'package:dompet_sheva/data/repositories/category_repository.dart';
import 'package:dompet_sheva/data/repositories/planning_repository.dart';
import 'package:dompet_sheva/data/repositories/wallet_repository.dart';
import 'package:dompet_sheva/data/store/finance_store.dart';

void main() {
  late AppDatabase db;
  late PlanningRepository repository;
  late int walletId;
  late int categoryId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = PlanningRepository(db);
    await BootstrapRepository(db).ensureSeeded();
    walletId = (await db.walletsDao.getAll()).first.id;
    categoryId = (await db.categoriesDao.getByType('expense')).first.id;
  });
  tearDown(() => db.close());

  Future<RecurringBillEntry> createBill({DateTime? due}) async {
    await repository.saveBill(
      title: 'Internet',
      amount: 250000,
      categoryId: categoryId,
      walletId: walletId,
      nextDueDate: due ?? DateTime(2026, 1, 31),
      frequency: 'monthly',
    );
    return (await db.recurringBillsDao.getAll()).single;
  }

  test('month end and leap day keep the original anchor', () {
    final february = PlanningRepository.nextDueDate(
      DateTime(2026, 1, 31),
      'monthly',
      31,
    );
    expect(february, DateTime(2026, 2, 28));
    expect(
      PlanningRepository.nextDueDate(february, 'monthly', 31),
      DateTime(2026, 3, 31),
    );
    expect(
      PlanningRepository.nextDueDate(DateTime(2027, 2, 28), 'yearly', 29),
      DateTime(2028, 2, 29),
    );
    expect(
      PlanningRepository.nextDueDate(DateTime(2026, 12, 31), 'weekly', 31),
      DateTime(2027, 1, 7),
    );
  });

  test(
    'bill is only a schedule until confirmed; payment advances one period',
    () async {
      final bill = await createBill();
      expect(await db.transactionsDao.getAll(), isEmpty);
      await repository.payBill(bill, paidAt: DateTime(2026, 2, 2));
      final payment = (await db.transactionsDao.getAll()).single;
      expect(payment.type, 'expense');
      expect(payment.amount, 250000);
      expect(payment.walletId, walletId);
      expect(payment.categoryId, categoryId);
      expect(payment.date, DateTime(2026, 2, 2));
      expect(
        (await db.recurringBillsDao.getById(bill.id))!.nextDueDate,
        DateTime(2026, 2, 28),
      );
      expect(
        (await WalletRepository(
          db,
        ).getWalletBalance(walletId: walletId))!.balance,
        -250000,
      );
    },
  );

  test(
    'stale payment and rapid double confirmation cannot duplicate expense',
    () async {
      final bill = await createBill();
      final first = repository.payBill(bill);
      final second = repository.payBill(bill);
      await first;
      await expectLater(second, throwsArgumentError);
      await expectLater(repository.payBill(bill), throwsArgumentError);
      expect(await db.transactionsDao.getAll(), hasLength(1));
      expect(
        (await db.recurringBillsDao.getById(bill.id))!.nextDueDate,
        DateTime(2026, 2, 28),
      );
    },
  );

  test('existing occurrence transaction is never overwritten', () async {
    final bill = await createBill();
    final id =
        1 +
        int.parse(
          sha256
              .convert(utf8.encode('bill:${bill.id}:2026-01-31'))
              .toString()
              .substring(0, 13),
          radix: 16,
        );
    final now = DateTime.now();
    await db.transactionsDao.add(
      TransactionEntriesCompanion.insert(
        id: Value(id),
        type: 'expense',
        amount: 120000,
        walletId: walletId,
        categoryId: Value(categoryId),
        date: now,
        note: const Value('Sudah dibayar'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await expectLater(repository.payBill(bill), throwsArgumentError);
    expect((await db.transactionsDao.getById(id))!.amount, 120000);
    expect(
      (await db.recurringBillsDao.getById(bill.id))!.nextDueDate,
      DateTime(2026, 1, 31),
    );
  });

  test(
    'payment beyond supported schedule range leaves expense and bill untouched',
    () async {
      final bill = await createBill(due: DateTime(2100, 12, 31));
      await expectLater(repository.payBill(bill), throwsArgumentError);
      expect(await db.transactionsDao.getAll(), isEmpty);
      expect(
        (await db.recurringBillsDao.getById(bill.id))!.nextDueDate,
        bill.nextDueDate,
      );
    },
  );

  test(
    'skip advances without expense and editing preserves month-end anchor',
    () async {
      final bill = await createBill();
      await repository.skipBill(bill);
      final next = (await db.recurringBillsDao.getById(bill.id))!;
      await repository.saveBill(
        id: next.id,
        title: 'Internet baru',
        amount: next.amount,
        categoryId: next.categoryId,
        walletId: next.walletId,
        nextDueDate: next.nextDueDate,
        frequency: next.frequency,
      );
      await repository.skipBill((await db.recurringBillsDao.getById(bill.id))!);
      expect(await db.transactionsDao.getAll(), isEmpty);
      expect(
        (await db.recurringBillsDao.getById(bill.id))!.nextDueDate,
        DateTime(2026, 3, 31),
      );
    },
  );

  test(
    'paused and archived references block payment; deletion stays safe',
    () async {
      final bill = await createBill();
      expect(await WalletRepository(db).deleteWallet(walletId), isNotNull);
      final category = (await db.categoriesDao.getAll()).firstWhere(
        (v) => v.id == categoryId,
      );
      expect(await CategoryRepository(db).deleteCategory(category), isNotNull);
      await repository.setBillActive(bill, false);
      await expectLater(
        repository.payBill((await db.recurringBillsDao.getById(bill.id))!),
        throwsArgumentError,
      );
      final paused = (await db.recurringBillsDao.getById(bill.id))!;
      await repository.setBillActive(paused, true);
      final wallet = (await db.walletsDao.getAll()).firstWhere(
        (v) => v.id == walletId,
      );
      await WalletRepository(db).setArchived(wallet, true);
      await expectLater(
        repository.payBill((await db.recurringBillsDao.getById(bill.id))!),
        throwsArgumentError,
      );
      expect(await db.transactionsDao.getAll(), isEmpty);
    },
  );

  test('failed schedule advancement rolls back expense atomically', () async {
    final bill = await createBill();
    await db.customStatement(
      "CREATE TRIGGER reject_advance BEFORE UPDATE ON recurring_bills BEGIN SELECT RAISE(ABORT, 'test rollback'); END;",
    );
    await expectLater(repository.payBill(bill), throwsA(isA<Exception>()));
    expect(await db.transactionsDao.getAll(), isEmpty);
    expect(
      (await db.recurringBillsDao.getById(bill.id))!.nextDueDate,
      bill.nextDueDate,
    );
  });

  test(
    'goal stores progress and deadline without changing cashflow or wallets',
    () async {
      await repository.saveGoal(
        name: 'Dana darurat',
        targetAmount: 10000000,
        savedAmount: 500000,
        targetDate: DateTime(2027, 12, 31),
      );
      final goal = (await db.savingsGoalsDao.getAll()).single;
      expect(goal.savedAmount, 500000);
      expect(goal.targetDate, DateTime(2027, 12, 31));
      await repository.saveGoal(
        id: goal.id,
        name: goal.name,
        targetAmount: goal.targetAmount,
        savedAmount: 11000000,
      );
      expect(
        (await db.savingsGoalsDao.getById(goal.id))!.savedAmount,
        11000000,
      );
      expect((await db.savingsGoalsDao.getById(goal.id))!.targetDate, isNull);
      expect(await db.transactionsDao.getAll(), isEmpty);
      expect(
        (await WalletRepository(
          db,
        ).getWalletBalance(walletId: walletId))!.balance,
        0,
      );
      await repository.deleteGoal(goal.id);
      expect(await db.savingsGoalsDao.getAll(), isEmpty);
    },
  );

  test(
    'invalid inputs and missing edits never create planning records',
    () async {
      await expectLater(
        repository.saveGoal(name: 'Target', targetAmount: 1, savedAmount: -1),
        throwsArgumentError,
      );
      await expectLater(
        repository.saveGoal(name: '', targetAmount: 1, savedAmount: 0),
        throwsArgumentError,
      );
      await expectLater(
        repository.saveGoal(
          id: 123,
          name: 'Target',
          targetAmount: 1,
          savedAmount: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.saveBill(
          title: 'Tagihan',
          amount: 0,
          categoryId: categoryId,
          walletId: walletId,
          nextDueDate: DateTime(2026),
          frequency: 'monthly',
        ),
        throwsArgumentError,
      );
      final incomeId = (await db.categoriesDao.getByType('income')).first.id;
      await expectLater(
        repository.saveBill(
          title: 'Tagihan',
          amount: 100,
          categoryId: incomeId,
          walletId: walletId,
          nextDueDate: DateTime(2026),
          frequency: 'monthly',
        ),
        throwsArgumentError,
      );
      expect(await db.recurringBillsDao.getAll(), isEmpty);
      expect(await db.savingsGoalsDao.getAll(), isEmpty);
    },
  );

  test(
    'atomic-capable store handles payment, skip, and pause through its compare-and-write API',
    () async {
      final bill = await createBill();
      final store = _AtomicTestStore(db);
      final atomicRepository = PlanningRepository(store);
      await atomicRepository.payBill(bill);
      expect(store.bills.payments, 1);
      expect(await db.transactionsDao.getAll(), hasLength(1));
      await atomicRepository.skipBill(
        (await db.recurringBillsDao.getById(bill.id))!,
      );
      await atomicRepository.setBillActive(
        (await db.recurringBillsDao.getById(bill.id))!,
        false,
      );
      expect(store.bills.advances, 2);
      final paused = (await db.recurringBillsDao.getById(bill.id))!;
      expect(paused.nextDueDate, DateTime(2026, 3, 31));
      expect(paused.isActive, false);
      expect(await db.transactionsDao.getAll(), hasLength(1));
    },
  );

  test(
    'same-second bill edits are rejected even when timestamps match',
    () async {
      final bill = await createBill();
      await db.recurringBillsDao.updateEntry(
        bill.copyWith(amount: 500000).toCompanion(true),
      );
      await expectLater(repository.payBill(bill), throwsArgumentError);
      expect(await db.transactionsDao.getAll(), isEmpty);
    },
  );

  test(
    'bill editing rejects a stale form snapshot before changing the schedule',
    () async {
      final original = await createBill();
      await repository.payBill(original);
      await expectLater(
        repository.saveBill(
          id: original.id,
          expectedBill: original,
          title: 'Stale edit',
          amount: original.amount,
          categoryId: categoryId,
          walletId: walletId,
          nextDueDate: original.nextDueDate,
          frequency: original.frequency,
        ),
        throwsArgumentError,
      );
      final current = (await db.recurringBillsDao.getById(original.id))!;
      expect(current.nextDueDate, DateTime(2026, 2, 28));
      expect(current.title, original.title);
      expect(await db.transactionsDao.getAll(), hasLength(1));
      await expectLater(
        repository.saveBill(
          id: original.id + 1,
          expectedBill: current,
          title: current.title,
          amount: current.amount,
          categoryId: categoryId,
          walletId: walletId,
          nextDueDate: current.nextDueDate,
          frequency: current.frequency,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'atomic-capable store compares existing bill edits through server API',
    () async {
      final original = await createBill();
      final store = _AtomicTestStore(db);
      final atomicRepository = PlanningRepository(store);
      await atomicRepository.saveBill(
        id: original.id,
        expectedBill: original,
        title: 'Internet baru',
        amount: 300000,
        categoryId: categoryId,
        walletId: walletId,
        nextDueDate: original.nextDueDate,
        frequency: original.frequency,
      );
      expect(store.bills.advances, 1);
      final current = (await db.recurringBillsDao.getById(original.id))!;
      expect(current.title, 'Internet baru');
      expect(current.amount, 300000);
      expect(current.nextDueDate, original.nextDueDate);
      expect(await db.transactionsDao.getAll(), isEmpty);
    },
  );

  test('creating from a month-end source preserves its original day', () async {
    await repository.saveBill(
      title: 'Internet',
      amount: 100000,
      walletId: walletId,
      categoryId: categoryId,
      nextDueDate: DateTime(2026, 2, 28),
      frequency: 'monthly',
      anchorDay: 31,
    );
    final bill = (await db.recurringBillsDao.getAll()).single;
    expect(bill.anchorDay, 31);
    await repository.skipBill(bill);
    expect(
      (await db.recurringBillsDao.getById(bill.id))!.nextDueDate,
      DateTime(2026, 3, 31),
    );
  });

  test(
    'version 3 upgrade adds planning tables and retains local data',
    () async {
      await db.close();
      final directory = await Directory.systemTemp.createTemp(
        'dompetku-migration-test-',
      );
      final file = File('${directory.path}/migration.sqlite');
      final original = AppDatabase(NativeDatabase(file));
      await BootstrapRepository(original).ensureSeeded();
      await original.customStatement('DROP TABLE recurring_bills');
      await original.customStatement('DROP TABLE savings_goals');
      await original.customStatement('PRAGMA user_version = 3');
      final walletsBefore = await original.walletsDao.getAll();
      await original.close();
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        expect(
          (await upgraded.walletsDao.getAll()).map((v) => v.toJson()),
          walletsBefore.map((v) => v.toJson()),
        );
        expect(await upgraded.recurringBillsDao.getAll(), isEmpty);
        expect(await upgraded.savingsGoalsDao.getAll(), isEmpty);
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          4,
        );
      } finally {
        await upgraded.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

/// Exercise the capability branch without requiring a network in unit tests.
class _AtomicTestStore implements FinanceStore {
  _AtomicTestStore(this.database) : bills = _AtomicTestBills(database);
  final AppDatabase database;
  final _AtomicTestBills bills;

  @override
  BillsStore get recurringBillsDao => bills;
  @override
  TransactionsStore get transactionsDao => database.transactionsDao;
  @override
  CategoriesStore get categoriesDao => database.categoriesDao;
  @override
  WalletsStore get walletsDao => database.walletsDao;
  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      database.transaction(action);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AtomicTestBills implements BillsStore, AtomicBillPayments {
  _AtomicTestBills(this.database);
  final AppDatabase database;
  int payments = 0;
  int advances = 0;

  @override
  Future<RecurringBillEntry?> getById(int id) =>
      database.recurringBillsDao.getById(id);
  @override
  Future<void> payAndAdvance(
    RecurringBillEntry expected,
    TransactionEntriesCompanion payment,
    RecurringBillEntry advanced,
  ) async {
    payments++;
    await database.transactionsDao.add(payment);
    await database.recurringBillsDao.updateEntry(advanced.toCompanion(true));
  }

  @override
  Future<void> advanceBill(
    RecurringBillEntry expected,
    RecurringBillEntry advanced,
  ) async {
    advances++;
    await database.recurringBillsDao.updateEntry(advanced.toCompanion(true));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
