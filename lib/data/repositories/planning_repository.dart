import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../local/database/app_database.dart';
import '../store/finance_store.dart';

/// Plans are metadata. Only confirming a bill creates an expense.
class PlanningRepository {
  PlanningRepository(this._database);

  final FinanceStore _database;
  Future<void> _pending = Future.value();
  static const frequencies = {'weekly', 'monthly', 'yearly'};
  static const maxAmount = 9007199254740991;

  Stream<List<RecurringBillEntry>> watchBills() =>
      _database.recurringBillsDao.watchAll();
  Stream<List<SavingsGoalEntry>> watchGoals() =>
      _database.savingsGoalsDao.watchAll();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> saveBill({
    int? id,
    RecurringBillEntry? expectedBill,
    required String title,
    required int amount,
    required int categoryId,
    required int walletId,
    required DateTime nextDueDate,
    required String frequency,
    int? anchorDay,
    bool isActive = true,
  }) => _serialize(() async {
    final name = _name(title, 'Nama tagihan');
    _money(amount);
    _date(nextDueDate);
    if (!frequencies.contains(frequency)) {
      throw ArgumentError('Pilih pengulangan yang valid.');
    }
    if (anchorDay != null && (anchorDay < 1 || anchorDay > 31)) {
      throw ArgumentError('Tanggal pengulangan harus antara 1 dan 31.');
    }
    if (expectedBill != null && expectedBill.id != id) {
      throw ArgumentError('Tagihan yang diedit tidak sesuai.');
    }
    await _validateExpenseReferences(walletId, categoryId);
    final existing = expectedBill != null
        ? await _currentBill(expectedBill)
        : id == null
        ? null
        : await _database.recurringBillsDao.getById(id);
    if (id != null && existing == null) {
      throw ArgumentError('Tagihan sudah dihapus.');
    }
    final due = _day(nextDueDate);
    final preserveAnchor =
        existing != null &&
        existing.frequency == frequency &&
        _day(existing.nextDueDate) == due;
    final now = DateTime.now();
    final entry = RecurringBillEntriesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      title: Value(name),
      amount: Value(amount),
      categoryId: Value(categoryId),
      walletId: Value(walletId),
      nextDueDate: Value(due),
      frequency: Value(frequency),
      anchorDay: Value(
        anchorDay ?? (preserveAnchor ? existing.anchorDay : due.day),
      ),
      isActive: Value(isActive),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
    );
    if (id == null) {
      await _database.recurringBillsDao.add(entry);
    } else {
      final bills = _database.recurringBillsDao;
      if (bills is AtomicBillPayments) {
        final desired = existing!.copyWith(
          title: name,
          amount: amount,
          categoryId: categoryId,
          walletId: walletId,
          nextDueDate: due,
          frequency: frequency,
          anchorDay:
              anchorDay ?? (preserveAnchor ? existing.anchorDay : due.day),
          isActive: isActive,
          updatedAt: now,
        );
        await (bills as AtomicBillPayments).advanceBill(existing, desired);
      } else {
        await bills.updateEntry(entry);
      }
    }
  });

  Future<void> deleteBill(int id) => _serialize(() async {
    await _database.recurringBillsDao.deleteById(id);
  });

  Future<void> setBillActive(RecurringBillEntry bill, bool active) =>
      _serialize(() async {
        final current = await _currentBill(bill);
        if (active) {
          await _validateExpenseReferences(
            current.walletId,
            current.categoryId,
          );
        }
        final advanced = current.copyWith(
          isActive: active,
          updatedAt: DateTime.now(),
        );
        final bills = _database.recurringBillsDao;
        if (bills is AtomicBillPayments) {
          await (bills as AtomicBillPayments).advanceBill(current, advanced);
        } else {
          await bills.updateEntry(advanced.toCompanion(true));
        }
      });

  Future<void> payBill(RecurringBillEntry bill, {DateTime? paidAt}) =>
      _serialize(
        () => _database.transaction(() async {
          final current = await _currentBill(bill);
          if (!current.isActive) {
            throw ArgumentError('Aktifkan tagihan terlebih dahulu.');
          }
          await _validateExpenseReferences(
            current.walletId,
            current.categoryId,
          );
          final paymentDate = paidAt ?? DateTime.now();
          _date(paymentDate);
          final transactionId = _paymentId(current);
          // The same occurrence has one stable ID on all account devices.
          if (await _database.transactionsDao.getById(transactionId) != null) {
            throw ArgumentError(
              'Pembayaran periode ini sudah dicatat. Muat ulang tagihan.',
            );
          }
          final now = DateTime.now();
          final advanced = _advanced(current);
          final payment = TransactionEntriesCompanion.insert(
            id: Value(transactionId),
            type: 'expense',
            amount: current.amount,
            categoryId: Value(current.categoryId),
            walletId: current.walletId,
            date: paymentDate,
            note: Value(
              'Tagihan ${current.title} (${_dateKey(current.nextDueDate)})',
            ),
            createdAt: now,
            updatedAt: now,
          );
          final bills = _database.recurringBillsDao;
          if (bills is AtomicBillPayments) {
            await (bills as AtomicBillPayments).payAndAdvance(
              current,
              payment,
              advanced,
            );
            return;
          }
          await _database.transactionsDao.add(payment);
          await bills.updateEntry(advanced.toCompanion(true));
        }),
      );

  Future<void> skipBill(RecurringBillEntry bill) => _serialize(
    () => _database.transaction(() async {
      final current = await _currentBill(bill);
      if (!current.isActive) {
        throw ArgumentError('Aktifkan tagihan terlebih dahulu.');
      }
      final advanced = _advanced(current);
      final bills = _database.recurringBillsDao;
      if (bills is AtomicBillPayments) {
        await (bills as AtomicBillPayments).advanceBill(current, advanced);
      } else {
        await bills.updateEntry(advanced.toCompanion(true));
      }
    }),
  );

  Future<RecurringBillEntry> _currentBill(RecurringBillEntry expected) async {
    final current = await _database.recurringBillsDao.getById(expected.id);
    if (current == null) throw ArgumentError('Tagihan sudah dihapus.');
    if (current.nextDueDate != expected.nextDueDate ||
        current.updatedAt != expected.updatedAt ||
        current.amount != expected.amount ||
        current.title != expected.title ||
        current.walletId != expected.walletId ||
        current.categoryId != expected.categoryId ||
        current.frequency != expected.frequency ||
        current.anchorDay != expected.anchorDay ||
        current.isActive != expected.isActive) {
      throw ArgumentError('Tagihan telah berubah. Periksa jadwal terbaru.');
    }
    return current;
  }

  RecurringBillEntry _advanced(RecurringBillEntry bill) {
    final next = nextDueDate(bill.nextDueDate, bill.frequency, bill.anchorDay);
    _date(next);
    return bill.copyWith(nextDueDate: next, updatedAt: DateTime.now());
  }

  /// Preserve the chosen day through short months and leap years.
  static DateTime nextDueDate(
    DateTime current,
    String frequency,
    int anchorDay,
  ) {
    if (!frequencies.contains(frequency) || anchorDay < 1 || anchorDay > 31) {
      throw ArgumentError('Jadwal tagihan tidak valid.');
    }
    if (frequency == 'weekly') {
      return DateTime(current.year, current.month, current.day + 7);
    }
    final year = current.year + (frequency == 'yearly' ? 1 : 0);
    final month = current.month + (frequency == 'monthly' ? 1 : 0);
    final last = DateTime(year, month + 1, 0);
    return DateTime(last.year, last.month, min(anchorDay, last.day));
  }

  Future<void> saveGoal({
    int? id,
    required String name,
    required int targetAmount,
    required int savedAmount,
    DateTime? targetDate,
  }) => _serialize(() async {
    final title = _name(name, 'Nama target');
    _money(targetAmount);
    _money(savedAmount, allowZero: true);
    if (targetDate != null) _date(targetDate);
    final existing = id == null
        ? null
        : await _database.savingsGoalsDao.getById(id);
    if (id != null && existing == null) {
      throw ArgumentError('Target sudah dihapus.');
    }
    final now = DateTime.now();
    final entry = SavingsGoalEntriesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      name: Value(title),
      targetAmount: Value(targetAmount),
      savedAmount: Value(savedAmount),
      targetDate: Value(targetDate == null ? null : _day(targetDate)),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
    );
    if (id == null) {
      await _database.savingsGoalsDao.add(entry);
    } else {
      await _database.savingsGoalsDao.updateEntry(entry);
    }
  });

  Future<void> deleteGoal(int id) => _serialize(() async {
    await _database.savingsGoalsDao.deleteById(id);
  });

  Future<void> _validateExpenseReferences(int walletId, int categoryId) async {
    final wallet = (await _database.walletsDao.getAll())
        .where((entry) => entry.id == walletId && !entry.isArchived)
        .firstOrNull;
    final category = (await _database.categoriesDao.getAll())
        .where(
          (entry) =>
              entry.id == categoryId &&
              !entry.isArchived &&
              (entry.type == 'expense' || entry.type == 'both'),
        )
        .firstOrNull;
    if (wallet == null) throw ArgumentError('Pilih dompet yang masih aktif.');
    if (category == null) {
      throw ArgumentError('Pilih kategori pengeluaran yang masih aktif.');
    }
  }

  static String _name(String raw, String label) {
    final value = raw.trim();
    if (value.isEmpty || value.length > 80) {
      throw ArgumentError('$label harus berisi 1–80 karakter.');
    }
    return value;
  }

  static void _money(int value, {bool allowZero = false}) {
    if (value < (allowZero ? 0 : 1) || value > maxAmount) {
      throw ArgumentError(
        allowZero
            ? 'Nominal tidak boleh negatif atau terlalu besar.'
            : 'Nominal harus lebih dari nol dan tidak terlalu besar.',
      );
    }
  }

  static void _date(DateTime value) {
    if (value.year < 2000 || value.year > 2100) {
      throw ArgumentError('Tanggal harus berada antara tahun 2000 dan 2100.');
    }
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static String _dateKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static int _paymentId(RecurringBillEntry bill) =>
      1 +
      int.parse(
        sha256
            .convert(
              utf8.encode('bill:${bill.id}:${_dateKey(bill.nextDueDate)}'),
            )
            .toString()
            .substring(0, 13),
        radix: 16,
      );
}
