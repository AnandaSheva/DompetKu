import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/bootstrap_repository.dart';
import 'package:dompet_sheva/data/repositories/wallet_repository.dart';

void main() {
  late AppDatabase db;
  late WalletRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = WalletRepository(db);
    await BootstrapRepository(db).ensureSeeded();
  });
  tearDown(() => db.close());

  test(
    'each bank keeps its own reserve without reducing recorded balances',
    () async {
      await repository.addWallet(
        name: 'Rekening A',
        type: 'bank',
        initialBalance: 200000,
        reservedBalance: 50000,
      );
      await repository.addWallet(
        name: 'Rekening B',
        type: 'bank',
        initialBalance: 100000,
        reservedBalance: 25000,
      );
      final wallets = await repository.getWallets();
      final a = wallets.singleWhere((w) => w.name == 'Rekening A');
      final b = wallets.singleWhere((w) => w.name == 'Rekening B');
      final category = (await db.categoriesDao.getByType('expense')).first;
      final now = DateTime.now();
      await db.transactionsDao.add(
        TransactionEntriesCompanion.insert(
          type: 'expense',
          amount: 20000,
          categoryId: Value(category.id),
          walletId: a.id,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final transferId = await db.transactionsDao.add(
        TransactionEntriesCompanion.insert(
          type: 'transfer',
          amount: 30000,
          walletId: a.id,
          transferWalletId: Value(b.id),
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final balances = await repository.watchWalletBalances().first;
      final aBalance = balances.singleWhere((w) => w.wallet.id == a.id);
      final bBalance = balances.singleWhere((w) => w.wallet.id == b.id);
      expect(aBalance.balance, 150000);
      expect(aBalance.availableBalance, 100000);
      expect(bBalance.balance, 130000);
      expect(bBalance.availableBalance, 105000);
      expect(aBalance.usesReservedBalance(100000), false);
      expect(aBalance.usesReservedBalance(100001), true);
      expect(
        (await repository.getWalletBalance(
          walletId: a.id,
          excludingTransactionId: transferId,
        ))!.balance,
        180000,
      );
    },
  );

  test(
    'reserve can exceed the current balance and be edited or cleared',
    () async {
      final bank = (await repository.getWallets()).singleWhere(
        (w) => w.type == 'bank',
      );
      await repository.updateWallet(
        wallet: bank,
        name: bank.name,
        type: 'bank',
        initialBalance: 10000,
        reservedBalance: 50000,
      );
      var balance = (await repository.getWalletBalance(walletId: bank.id))!;
      expect(balance.balance, 10000);
      expect(balance.availableBalance, 0);
      expect(balance.usesReservedBalance(1), true);
      await repository.updateWallet(
        wallet: balance.wallet,
        name: bank.name,
        type: 'bank',
        initialBalance: 10000,
        reservedBalance: 5000,
      );
      balance = (await repository.getWalletBalance(walletId: bank.id))!;
      expect(balance.availableBalance, 5000);
      await repository.updateWallet(
        wallet: balance.wallet,
        name: bank.name,
        type: 'cash',
        initialBalance: 10000,
      );
      balance = (await repository.getWalletBalance(walletId: bank.id))!;
      expect(balance.reservedBalance, 0);
      expect(balance.wallet.reservedBalance, 0);
      expect(balance.availableBalance, 10000);
      await repository.addWallet(
        name: 'Tunai baru',
        type: 'cash',
        reservedBalance: 50000,
      );
      expect(
        (await repository.getWallets())
            .singleWhere((w) => w.name == 'Tunai baru')
            .reservedBalance,
        0,
      );
    },
  );

  test('invalid reserves are rejected without changing wallets', () async {
    final before = await repository.getWallets();
    final bank = before.singleWhere((w) => w.type == 'bank');
    for (final amount in [-1, 9007199254740992]) {
      await expectLater(
        repository.addWallet(
          name: 'Baru',
          type: 'bank',
          reservedBalance: amount,
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.updateWallet(
          wallet: bank,
          name: bank.name,
          type: 'bank',
          initialBalance: 0,
          reservedBalance: amount,
        ),
        throwsArgumentError,
      );
    }
    expect(await repository.getWallets(), before);
  });

  test(
    'version 4 upgrade preserves wallets and transactions with zero reserves',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dompetku-reserve-migration-',
      );
      final file = File('${directory.path}/migration.sqlite');
      final original = AppDatabase(NativeDatabase(file));
      final upgraded = AppDatabase(NativeDatabase(file));
      var originalClosed = false;
      try {
        await BootstrapRepository(original).ensureSeeded();
        final wallets = await original.walletsDao.getAll();
        final now = DateTime.now();
        await original.transactionsDao.add(
          TransactionEntriesCompanion.insert(
            type: 'transfer',
            amount: 1000,
            walletId: wallets.first.id,
            transferWalletId: Value(wallets.last.id),
            date: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final transactions = await original.transactionsDao.getAll();
        await original.customStatement(
          'ALTER TABLE wallets DROP COLUMN reserved_balance',
        );
        await original.customStatement(
          'ALTER TABLE wallets DROP COLUMN deleted_at',
        );
        await original.customStatement('PRAGMA user_version = 4');
        await original.close();
        originalClosed = true;
        expect(await upgraded.walletsDao.getAll(), wallets);
        expect(await upgraded.transactionsDao.getAll(), transactions);
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          6,
        );
        expect(
          await upgraded.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        if (!originalClosed) await original.close();
        await upgraded.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
