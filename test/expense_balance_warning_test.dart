import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/app/theme/app_theme.dart';
import 'package:dompet_sheva/core/enums/transaction_type.dart';
import 'package:dompet_sheva/core/formatters/currency_formatter.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/app_models.dart';
import 'package:dompet_sheva/data/store/finance_store.dart';
import 'package:dompet_sheva/shared/components/add_transaction_sheet.dart';
import 'package:dompet_sheva/shared/components/amount_keypad.dart';
import 'package:dompet_sheva/shared/components/transaction_type_segmented_control.dart';
import 'package:dompet_sheva/shared/widgets/top_toast.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('warns using the latest wallet balance and allows correction', (
    tester,
  ) async {
    final store = _TestStore(initialBalance: 10000);
    await _openSheet(tester, store, amount: 15000);
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();

    expect(find.text('Arus kas dompet akan minus'), findsOneWidget);
    expect(
      find.textContaining(
        'Saldo setelah transaksi: ${CurrencyFormatter.rupiah(-5000)}',
      ),
      findsOneWidget,
    );
    expect(store.transactionsDao.writes, isEmpty);

    await tester.tap(find.text('Ubah transaksi'));
    await tester.pumpAndSettle();
    expect(find.byType(AddTransactionSheet), findsOneWidget);
    expect(store.transactionsDao.writes, isEmpty);
  });

  testWidgets('saves an overdrawn expense only after confirmation', (
    tester,
  ) async {
    final store = _TestStore(initialBalance: 10000);
    await _openSheet(tester, store, amount: 15000);
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(store.transactionsDao.writes, isEmpty);

    await tester.tap(find.text('Tetap simpan'));
    await tester.pumpAndSettle();
    TopToast.dismiss();
    expect(store.transactionsDao.writes.single.amount.value, 15000);
    expect(find.byType(AddTransactionSheet), findsNothing);
  });

  for (final amount in [5000, 10000]) {
    testWidgets('saves expense $amount without warning when funds suffice', (
      tester,
    ) async {
      final store = _TestStore(initialBalance: 10000);
      await _openSheet(tester, store, amount: amount);
      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pumpAndSettle();

      expect(find.text('Arus kas dompet akan minus'), findsNothing);
      expect(store.transactionsDao.writes.single.amount.value, amount);
      TopToast.dismiss();
    });
  }

  testWidgets('excludes the old expense when editing its amount', (
    tester,
  ) async {
    final store = _TestStore(initialBalance: 15000);
    final existing = _transaction(type: TransactionType.expense, amount: 5000);
    store.transactionsDao.entries.add(existing);
    await _openSheet(tester, store, amount: 15000, existing: existing);
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();

    expect(find.text('Arus kas dompet akan minus'), findsNothing);
    expect(store.transactionsDao.writes.single.id.value, existing.id);
    expect(store.transactionsDao.writes.single.amount.value, 15000);
    TopToast.dismiss();
  });

  testWidgets('removes old income before previewing a change to expense', (
    tester,
  ) async {
    final store = _TestStore(initialBalance: 0);
    final existing = _transaction(type: TransactionType.income, amount: 10000);
    store.transactionsDao.entries.add(existing);
    await _openSheet(tester, store, amount: 5000, existing: existing);
    tester
        .widget<TransactionTypeSegmentedControl>(
          find.byType(TransactionTypeSegmentedControl),
        )
        .onChanged(TransactionType.expense.index);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();

    expect(find.text('Arus kas dompet akan minus'), findsOneWidget);
    expect(store.transactionsDao.writes, isEmpty);
  });

  for (final type in [TransactionType.income, TransactionType.transfer]) {
    testWidgets('does not apply the expense warning to ${type.value}', (
      tester,
    ) async {
      final store = _TestStore(initialBalance: 0);
      await _openSheet(tester, store, amount: 15000);
      tester
          .widget<TransactionTypeSegmentedControl>(
            find.byType(TransactionTypeSegmentedControl),
          )
          .onChanged(type.index);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pumpAndSettle();

      expect(find.text('Arus kas dompet akan minus'), findsNothing);
      expect(store.transactionsDao.writes.single.type.value, type.value);
      TopToast.dismiss();
    });
  }
}

Future<void> _openSheet(
  WidgetTester tester,
  _TestStore store, {
  required int amount,
  TransactionEntry? existing,
}) async {
  final wallets = await store.walletsDao.getAll();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(store),
        // A stale displayed balance must not bypass the pre-save check.
        walletBalancesProvider.overrideWith(
          (ref) => Stream.value([
            for (final wallet in wallets)
              WalletBalance(wallet: wallet, balance: 999999),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => AddTransactionSheet(
                  transaction: existing == null
                      ? null
                      : TransactionDetail(
                          transaction: existing,
                          wallet: wallets.first,
                        ),
                ),
              ),
              child: const Text('Tambah transaksi'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Tambah transaksi'));
  await tester.pumpAndSettle();
  final keypad = tester.widget<AmountKeypad>(find.byType(AmountKeypad));
  if (existing != null) {
    for (var i = 0; i < existing.amount.toString().length; i++) {
      keypad.onBackspacePressed();
    }
  }
  for (final digit in amount.toString().split('')) {
    keypad.onDigitPressed(digit);
  }
  await tester.pumpAndSettle();
}

final _now = DateTime(2026, 11, 13);

TransactionEntry _transaction({
  required TransactionType type,
  required int amount,
}) => TransactionEntry(
  id: 7,
  type: type.value,
  amount: amount,
  categoryId: 1,
  walletId: 1,
  date: _now,
  createdAt: _now,
  updatedAt: _now,
);

class _TestStore implements FinanceStore {
  _TestStore({required int initialBalance})
    : walletsDao = _Wallets(initialBalance);

  @override
  final _Wallets walletsDao;
  @override
  final _Transactions transactionsDao = _Transactions();
  @override
  final _Categories categoriesDao = _Categories();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wallets implements WalletsStore {
  _Wallets(this.initialBalance);
  final int initialBalance;

  @override
  Future<List<WalletEntry>> getAll() async => [
    for (final id in [1, 2])
      WalletEntry(
        id: id,
        name: id == 1 ? 'Tunai' : 'Bank',
        type: 'cash',
        initialBalance: initialBalance,
        isArchived: false,
        createdAt: _now,
        updatedAt: _now,
      ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transactions implements TransactionsStore {
  final entries = <TransactionEntry>[];
  final writes = <TransactionEntriesCompanion>[];

  @override
  Future<List<TransactionEntry>> getAll() async => entries;
  @override
  Future<TransactionEntry?> getById(int id) async =>
      entries.where((entry) => entry.id == id).firstOrNull;
  @override
  Future<int> add(TransactionEntriesCompanion entry) async {
    writes.add(entry);
    return 1;
  }

  @override
  Future<void> updateEntry(TransactionEntriesCompanion entry) async {
    writes.add(entry);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Categories implements CategoriesStore {
  @override
  Stream<List<CategoryEntry>> watchAll() => Stream.value([
    CategoryEntry(
      id: 1,
      name: 'Lainnya',
      type: 'both',
      groupName: 'Umum',
      iconKey: 'category',
      colorValue: 0xff2563eb,
      isDefault: false,
      isArchived: false,
      createdAt: _now,
      updatedAt: _now,
    ),
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
