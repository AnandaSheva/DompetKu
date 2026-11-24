import 'package:drift/drift.dart';

import '../../core/enums/wallet_type.dart';
import '../../core/helpers/calculation_helper.dart';
import '../../core/helpers/stream_combiner.dart';
import '../local/database/app_database.dart';
import '../store/finance_store.dart';
import 'app_models.dart';

class WalletRepository {
  const WalletRepository(this._database);

  final FinanceStore _database;

  Stream<List<WalletBalance>> watchWalletBalances() {
    return combineLatest<List<WalletBalance>>(
      [_database.walletsDao.watchAll(), _database.transactionsDao.watchAll()],
      (values) {
        final wallets = [
          for (final wallet in values[0] as List<WalletEntry>)
            if (wallet.deletedAt == null) wallet,
        ];
        final balances = CalculationHelper.walletBalances(
          initialBalances: {
            for (final wallet in wallets) wallet.id: wallet.initialBalance,
          },
          transactions: (values[1] as List<TransactionEntry>).map(
            (transaction) => (
              walletId: transaction.walletId,
              transferWalletId: transaction.transferWalletId,
              type: transaction.type,
              amount: transaction.amount,
            ),
          ),
        );
        return [
          for (final wallet in wallets)
            WalletBalance(wallet: wallet, balance: balances[wallet.id]!),
        ];
      },
    );
  }

  Future<List<WalletEntry>> getWallets() async {
    return (await _database.walletsDao.getAll())
        .where((wallet) => wallet.deletedAt == null)
        .toList();
  }

  Future<WalletBalance?> getWalletBalance({
    required int walletId,
    int? excludingTransactionId,
  }) async {
    final wallets = await getWallets();
    final wallet = wallets.where((wallet) => wallet.id == walletId).firstOrNull;
    if (wallet == null) return null;

    final transactions = await _database.transactionsDao.getAll();
    return _walletBalance(
      wallet,
      transactions.where((entry) => entry.id != excludingTransactionId),
    );
  }

  WalletBalance _walletBalance(
    WalletEntry wallet,
    Iterable<TransactionEntry> transactions,
  ) => WalletBalance(
    wallet: wallet,
    balance: CalculationHelper.walletBalance(
      walletId: wallet.id,
      initialBalance: wallet.initialBalance,
      transactions: transactions.map(
        (transaction) => (
          walletId: transaction.walletId,
          transferWalletId: transaction.transferWalletId,
          type: transaction.type,
          amount: transaction.amount,
        ),
      ),
    ),
  );

  Future<void> addWallet({
    required String name,
    required String type,
    int initialBalance = 0,
    int reservedBalance = 0,
  }) async {
    final reserve = _reservedBalance(type, reservedBalance);
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Nama dompet belum diisi.');
    }
    final duplicateCount = await _database.walletsDao.countDuplicate(
      name: trimmedName,
    );
    if (duplicateCount > 0) {
      throw ArgumentError('Nama dompet sudah digunakan.');
    }
    final now = DateTime.now();
    await _database.walletsDao.add(
      WalletEntriesCompanion.insert(
        name: trimmedName,
        type: type,
        initialBalance: Value(initialBalance),
        reservedBalance: Value(reserve),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateWallet({
    required WalletEntry wallet,
    required String name,
    required String type,
    required int initialBalance,
    int? reservedBalance,
  }) async {
    await _requireExistingWallet(wallet.id);
    final reserve = _reservedBalance(
      type,
      reservedBalance ?? wallet.reservedBalance,
    );
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Nama dompet belum diisi.');
    }
    final duplicateCount = await _database.walletsDao.countDuplicate(
      name: trimmedName,
      exceptId: wallet.id,
    );
    if (duplicateCount > 0) {
      throw ArgumentError('Nama dompet sudah digunakan.');
    }
    await _database.walletsDao.updateEntry(
      wallet
          .copyWith(
            name: trimmedName,
            type: type,
            initialBalance: initialBalance,
            reservedBalance: reserve,
            updatedAt: DateTime.now(),
          )
          .toCompanion(true),
    );
  }

  int _reservedBalance(String type, int amount) {
    if (amount < 0 || amount > 9007199254740991) {
      throw ArgumentError(
        'Saldo endapan harus berupa nominal Rupiah yang valid.',
      );
    }
    return type == WalletType.bank.value ? amount : 0;
  }

  Future<String?> deleteWallet(int walletId) async {
    await _database.transaction(() async {
      final wallet = (await _database.walletsDao.getAll())
          .where((entry) => entry.id == walletId)
          .firstOrNull;
      if (wallet == null || wallet.deletedAt != null) return;
      final now = DateTime.now();
      // A tombstone keeps both sides of transfers and backup references intact.
      await _database.walletsDao.updateEntry(
        wallet
            .copyWith(deletedAt: Value(now), isArchived: true, updatedAt: now)
            .toCompanion(true),
      );
      for (final bill in await _database.recurringBillsDao.getAll()) {
        if (bill.walletId == walletId && bill.isActive) {
          await _database.recurringBillsDao.updateEntry(
            bill.copyWith(isActive: false, updatedAt: now).toCompanion(true),
          );
        }
      }
    });
    return null;
  }

  Future<int> transactionCount(int walletId) {
    return _database.transactionsDao.countByWallet(walletId);
  }

  Future<void> setArchived(WalletEntry wallet, bool value) async {
    await _requireExistingWallet(wallet.id);
    await _database.walletsDao.updateEntry(
      wallet
          .copyWith(isArchived: value, updatedAt: DateTime.now())
          .toCompanion(true),
    );
  }

  Future<void> _requireExistingWallet(int id) async {
    final wallets = await getWallets();
    if (!wallets.any((wallet) => wallet.id == id)) {
      throw ArgumentError('Dompet sudah dihapus.');
    }
  }
}
