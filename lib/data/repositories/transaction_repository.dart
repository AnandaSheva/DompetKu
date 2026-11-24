import 'package:drift/drift.dart';

import '../../core/enums/transaction_type.dart';
import '../../core/helpers/stream_combiner.dart';
import '../local/database/app_database.dart';
import '../store/finance_store.dart';
import 'app_models.dart';

class TransactionRepository {
  const TransactionRepository(this._database);

  final FinanceStore _database;

  Stream<List<TransactionDetail>> watchDetails() {
    return combineLatest<List<TransactionDetail>>(
      [
        _database.transactionsDao.watchAll(),
        _database.categoriesDao.watchAll(),
        _database.walletsDao.watchAll(),
      ],
      (values) {
        return _details(
          transactions: values[0] as List<TransactionEntry>,
          categories: values[1] as List<CategoryEntry>,
          wallets: values[2] as List<WalletEntry>,
        );
      },
    );
  }

  Future<List<TransactionDetail>> getDetails() async {
    final transactions = await _database.transactionsDao.getAll();
    final categories = await _database.categoriesDao.getAll();
    final wallets = await _database.walletsDao.getAll();
    return _details(
      transactions: transactions,
      categories: categories,
      wallets: wallets,
    );
  }

  Future<void> save({
    int? id,
    required TransactionType type,
    required int amount,
    int? categoryId,
    required int walletId,
    int? transferWalletId,
    required DateTime date,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Masukkan nominal terlebih dahulu.');
    }
    if (type != TransactionType.transfer && categoryId == null) {
      throw ArgumentError('Pilih kategori terlebih dahulu.');
    }
    if (type == TransactionType.transfer) {
      if (transferWalletId == null) {
        throw ArgumentError('Pilih dompet tujuan terlebih dahulu.');
      }
      if (transferWalletId == walletId) {
        throw ArgumentError('Pilih dompet tujuan yang berbeda.');
      }
    }

    final now = DateTime.now();
    final existing = id == null
        ? null
        : await _database.transactionsDao.getById(id);
    final wallets = await _database.walletsDao.getAll();
    if (existing != null) _requireEditable(existing, wallets);
    for (final selectedId in [
      walletId,
      if (transferWalletId != null && type == TransactionType.transfer)
        transferWalletId,
    ]) {
      if (!wallets.any(
        (wallet) => wallet.id == selectedId && wallet.deletedAt == null,
      )) {
        throw ArgumentError('Dompet sudah dihapus. Pilih dompet lain.');
      }
    }
    final companion = TransactionEntriesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      type: Value(type.value),
      amount: Value(amount),
      categoryId: Value(type == TransactionType.transfer ? null : categoryId),
      walletId: Value(walletId),
      transferWalletId: Value(
        type == TransactionType.transfer ? transferWalletId : null,
      ),
      date: Value(date),
      note: Value(note?.trim().isEmpty ?? true ? null : note!.trim()),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
    );

    if (id == null) {
      await _database.transactionsDao.add(companion);
    } else {
      await _database.transactionsDao.updateEntry(companion);
    }
  }

  Future<void> delete(int id) async {
    final existing = await _database.transactionsDao.getById(id);
    if (existing == null) return;
    _requireEditable(existing, await _database.walletsDao.getAll());
    await _database.transactionsDao.deleteById(id);
  }

  void _requireEditable(TransactionEntry entry, List<WalletEntry> wallets) {
    if (wallets.any(
      (wallet) =>
          wallet.deletedAt != null &&
          (wallet.id == entry.walletId || wallet.id == entry.transferWalletId),
    )) {
      throw ArgumentError(
        'Log transaksi dari dompet yang dihapus hanya bisa dibaca.',
      );
    }
  }

  List<TransactionDetail> _details({
    required List<TransactionEntry> transactions,
    required List<CategoryEntry> categories,
    required List<WalletEntry> wallets,
  }) {
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final walletsById = {for (final wallet in wallets) wallet.id: wallet};

    return [
      for (final transaction in transactions)
        if (walletsById[transaction.walletId] != null)
          TransactionDetail(
            transaction: transaction,
            category: categoriesById[transaction.categoryId],
            wallet: walletsById[transaction.walletId]!,
            transferWallet: walletsById[transaction.transferWalletId],
          ),
    ];
  }
}
