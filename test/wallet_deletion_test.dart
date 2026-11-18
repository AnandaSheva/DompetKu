import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dompet_sheva/core/enums/transaction_type.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/backup_repository.dart';
import 'package:dompet_sheva/data/repositories/bootstrap_repository.dart';
import 'package:dompet_sheva/data/repositories/dashboard_repository.dart';
import 'package:dompet_sheva/data/repositories/planning_repository.dart';
import 'package:dompet_sheva/data/repositories/transaction_repository.dart';
import 'package:dompet_sheva/data/repositories/wallet_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  late AppDatabase db;
  late WalletRepository wallets;
  late TransactionRepository transactions;
  late PlanningRepository planning;
  late WalletEntry removed;
  late WalletEntry retained;
  late int categoryId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await BootstrapRepository(db).ensureSeeded();
    wallets = WalletRepository(db);
    transactions = TransactionRepository(db);
    planning = PlanningRepository(db);
    await wallets.addWallet(name: 'Lama', type: 'bank', initialBalance: 100000);
    await wallets.addWallet(
      name: 'Aktif',
      type: 'cash',
      initialBalance: 200000,
    );
    final entries = await wallets.getWallets();
    removed = entries.singleWhere((w) => w.name == 'Lama');
    retained = entries.singleWhere((w) => w.name == 'Aktif');
    categoryId = (await db.categoriesDao.getByType('expense')).first.id;
    final incomeCategory = (await db.categoriesDao.getByType(
      'income',
    )).first.id;
    for (final item in [
      (TransactionType.income, removed.id, null, incomeCategory, 50000),
      (TransactionType.expense, removed.id, null, categoryId, 20000),
      (TransactionType.transfer, removed.id, retained.id, null, 30000),
      (TransactionType.transfer, retained.id, removed.id, null, 10000),
      (TransactionType.expense, retained.id, null, categoryId, 5000),
    ]) {
      await transactions.save(
        type: item.$1,
        walletId: item.$2,
        transferWalletId: item.$3,
        categoryId: item.$4,
        amount: item.$5,
        date: DateTime.now(),
        note: 'Riwayat asli',
      );
    }
  });
  tearDown(() => db.close());

  test(
    'deletion retains logs and both transfer balances without losing reports',
    () async {
      final before = await db.transactionsDao.getAll();
      final summaryBefore = await DashboardRepository(db).watchSummary().first;
      expect(await wallets.deleteWallet(removed.id), isNull);
      expect(await wallets.getWalletBalance(walletId: removed.id), isNull);
      expect(
        (await wallets.getWallets()).any((w) => w.id == removed.id),
        false,
      );
      expect(
        (await wallets.watchWalletBalances().first).any(
          (w) => w.wallet.id == removed.id,
        ),
        false,
      );
      expect(await db.transactionsDao.getAll(), before);
      final details = await transactions.getDetails();
      expect(details, hasLength(5));
      expect(details.where((d) => d.isLog), hasLength(4));
      expect(
        details
            .where((d) => d.isLog)
            .every((d) => d.transaction.note == 'Riwayat asli'),
        true,
      );
      expect(
        (await wallets.getWalletBalance(walletId: retained.id))!.balance,
        215000,
      );
      final summary = await DashboardRepository(db).watchSummary().first;
      expect(summary.walletCount, summaryBefore.walletCount - 1);
      expect(summary.totalBalance, summaryBefore.totalBalance - 110000);
      expect(summary.monthlyIncome, summaryBefore.monthlyIncome);
      expect(summary.monthlyExpense, summaryBefore.monthlyExpense);
      expect(summary.monthlyIncome, 50000);
      expect(summary.monthlyExpense, 25000);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('logs cannot be edited, deleted or moved to an active wallet', () async {
    await wallets.deleteWallet(removed.id);
    for (final log in (await transactions.getDetails()).where((d) => d.isLog)) {
      await expectLater(
        transactions.delete(log.transaction.id),
        throwsArgumentError,
      );
      await expectLater(
        transactions.save(
          id: log.transaction.id,
          type: TransactionType.expense,
          amount: 1,
          categoryId: categoryId,
          walletId: retained.id,
          date: DateTime.now(),
        ),
        throwsArgumentError,
      );
    }
    for (final type in TransactionType.values) {
      await expectLater(
        transactions.save(
          type: type,
          amount: 1,
          categoryId: categoryId,
          walletId: removed.id,
          transferWalletId: retained.id,
          date: DateTime.now(),
        ),
        throwsArgumentError,
      );
    }
    await expectLater(
      transactions.save(
        type: TransactionType.transfer,
        amount: 1,
        walletId: retained.id,
        transferWalletId: removed.id,
        date: DateTime.now(),
      ),
      throwsArgumentError,
    );
    final normal = (await transactions.getDetails()).singleWhere(
      (d) => !d.isLog,
    );
    await transactions.delete(normal.transaction.id);
    expect(await db.transactionsDao.getAll(), hasLength(4));
  });

  test(
    'deletion pauses linked bills and permits reusing the name without reviving history',
    () async {
      for (final wallet in [removed, retained]) {
        await planning.saveBill(
          title: wallet.name,
          amount: 10000,
          categoryId: categoryId,
          walletId: wallet.id,
          nextDueDate: DateTime.now(),
          frequency: 'monthly',
        );
      }
      await wallets.deleteWallet(removed.id);
      await wallets.deleteWallet(removed.id);
      final bills = await db.recurringBillsDao.getAll();
      final paused = bills.singleWhere((b) => b.walletId == removed.id);
      expect(paused.isActive, false);
      expect(
        bills.singleWhere((b) => b.walletId == retained.id).isActive,
        true,
      );
      await expectLater(
        planning.setBillActive(paused, true),
        throwsArgumentError,
      );
      await expectLater(
        wallets.setArchived(removed, false),
        throwsArgumentError,
      );
      await expectLater(
        wallets.updateWallet(
          wallet: removed,
          name: 'Baru',
          type: 'cash',
          initialBalance: 0,
        ),
        throwsArgumentError,
      );
      await wallets.addWallet(name: 'Lama', type: 'bank');
      final replacement = (await wallets.getWallets()).singleWhere(
        (w) => w.name == 'Lama',
      );
      expect(replacement.id, isNot(removed.id));
      expect(
        (await wallets.getWalletBalance(walletId: replacement.id))!.balance,
        0,
      );
      expect(
        (await transactions.getDetails()).where((d) => d.isLog),
        hasLength(4),
      );
    },
  );

  test(
    'backup restores deletion and readable history and accepts older wallets',
    () async {
      await wallets.deleteWallet(removed.id);
      final backup = BackupRepository(db);
      final payload = await backup.exportPayload();
      await backup.restoreImport(backup.previewFromJson(jsonEncode(payload)));
      expect(await wallets.getWalletBalance(walletId: removed.id), isNull);
      expect(
        (await transactions.getDetails()).where((d) => d.isLog),
        hasLength(4),
      );
      expect(
        (await wallets.getWalletBalance(walletId: retained.id))!.balance,
        215000,
      );
      final invalid = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      (invalid['wallets'] as List).first['deleted_at'] = 'invalid';
      expect(
        () => backup.previewFromJson(jsonEncode(invalid)),
        throwsFormatException,
      );
      expect(await wallets.getWalletBalance(walletId: removed.id), isNull);
      for (final wallet in payload['wallets'] as List) {
        (wallet as Map).remove('deleted_at');
      }
      await backup.restoreImport(backup.previewFromJson(jsonEncode(payload)));
      expect(
        (await db.walletsDao.getAll()).every((w) => w.deletedAt == null),
        true,
      );
    },
  );
}
