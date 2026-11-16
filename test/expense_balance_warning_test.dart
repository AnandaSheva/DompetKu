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
import 'package:dompet_sheva/shared/components/category_choice_chip.dart';
import 'package:dompet_sheva/shared/components/category_group_section.dart';
import 'package:dompet_sheva/shared/components/transaction_type_segmented_control.dart';
import 'package:dompet_sheva/shared/helpers/category_icon_mapper.dart';
import 'package:dompet_sheva/shared/widgets/top_toast.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
    'expanded grid selects a category once and saves its original ID',
    (tester) async {
      final store = _TestStore(
        initialBalance: 10000,
        categories: _gridCategories(),
      );
      await _openSheet(tester, store, amount: 5000);
      expect(find.byType(CategoryChoiceChip), findsNWidgets(9));
      expect(
        find.byKey(const ValueKey('transaction-category-12')),
        findsNothing,
      );
      final scrollable = find
          .descendant(
            of: find.byType(AddTransactionSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Lihat semua (12)'),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lihat semua (12)'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryChoiceChip), findsNWidgets(12));
      final target = find.byKey(const ValueKey('transaction-category-12'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(tester.widget<CategoryChoiceChip>(target).selected, isTrue);
      expect(
        tester.widget<CategoryChoiceChip>(target).icon,
        categoryIconForEntry(store.categoriesDao.entries[11]),
      );
      await tester.ensureVisible(find.text('Tampilkan lebih sedikit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tampilkan lebih sedikit'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryChoiceChip), findsNWidgets(9));
      expect(tester.widget<CategoryChoiceChip>(target).selected, isTrue);
      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pumpAndSettle();
      expect(store.transactionsDao.writes.single.categoryId.value, 12);
      TopToast.dismiss();
    },
  );

  testWidgets('editing opens the saved category group', (tester) async {
    final store = _TestStore(
      initialBalance: 10000,
      categories: [
        for (final category in _gridCategories())
          category.id == 12
              ? category.copyWith(groupName: 'Kesehatan')
              : category,
      ],
    );
    final existing = _transaction(
      type: TransactionType.expense,
      amount: 5000,
      categoryId: 12,
    );
    store.transactionsDao.entries.add(existing);
    await _openSheet(tester, store, amount: 5000, existing: existing);
    final target = find.byKey(const ValueKey('transaction-category-12'));
    expect(tester.widget<CategoryChoiceChip>(target).selected, isTrue);
    expect(
      tester
          .widget<CategoryGroupSection>(
            find.byKey(const ValueKey('transaction-category-group-Kesehatan')),
          )
          .expanded,
      isTrue,
    );
    expect(
      tester
          .widget<CategoryGroupSection>(
            find.byKey(
              const ValueKey('transaction-category-group-Kebutuhan Harian'),
            ),
          )
          .expanded,
      isFalse,
    );
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(store.transactionsDao.writes.single.categoryId.value, 12);
    TopToast.dismiss();
  });

  testWidgets(
    'only the opened group shows icons and selecting it saves the category',
    (tester) async {
      final store = _TestStore(
        initialBalance: 10000,
        categories: [
          for (final category in _gridCategories())
            category.id == 12
                ? category.copyWith(groupName: 'Kesehatan')
                : category,
        ],
      );
      await _openSheet(tester, store, amount: 5000);
      expect(find.byType(CategoryChoiceChip), findsNWidgets(9));
      expect(
        find.byKey(const ValueKey('transaction-category-12')),
        findsNothing,
      );
      final scrollable = find
          .descendant(
            of: find.byType(AddTransactionSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Kesehatan'),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kesehatan'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryChoiceChip), findsOneWidget);
      expect(
        find.byKey(const ValueKey('transaction-category-1')),
        findsNothing,
      );
      final target = find.byKey(const ValueKey('transaction-category-12'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(tester.widget<CategoryChoiceChip>(target).selected, isTrue);
      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pumpAndSettle();
      expect(store.transactionsDao.writes.single.categoryId.value, 12);
      TopToast.dismiss();
    },
  );

  testWidgets('income and transfer keep their own category rules', (
    tester,
  ) async {
    final store = _TestStore(
      initialBalance: 10000,
      categories: _gridCategories(),
    );
    await _openSheet(tester, store, amount: 5000);
    expect(find.byKey(const ValueKey('transaction-category-20')), findsNothing);
    expect(find.byKey(const ValueKey('transaction-category-21')), findsNothing);
    final control = tester.widget<TransactionTypeSegmentedControl>(
      find.byType(TransactionTypeSegmentedControl),
    );
    control.onChanged(TransactionType.income.index);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryChoiceChip), findsOneWidget);
    expect(
      find.byKey(const ValueKey('transaction-category-20')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('transaction-category-21')), findsNothing);
    expect(find.byKey(const ValueKey('transaction-category-1')), findsNothing);
    final scrollable = find
        .descendant(
          of: find.byType(AddTransactionSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Kebutuhan Harian'),
      200,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kebutuhan Harian'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('transaction-category-1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('transaction-category-20')), findsNothing);
    control.onChanged(TransactionType.transfer.index);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryChoiceChip), findsNothing);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final width in [320.0, 800.0]) {
      testWidgets('category grid fits ${theme.brightness.name} at $width', (
        tester,
      ) async {
        final store = _TestStore(
          initialBalance: 10000,
          categories: [
            ..._gridCategories(),
            if (width >= 600)
              for (var id = 30; id < 50; id++)
                _gridCategories()[1].copyWith(id: id, name: 'Tambahan $id'),
          ],
        );
        await _openSheet(
          tester,
          store,
          amount: 5000,
          theme: theme,
          width: width,
          scale: 1.3,
        );
        final scrollable = find
            .descendant(
              of: find.byType(AddTransactionSheet),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byType(CategoryGroupSection),
          200,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        final section = tester.widget<CategoryGroupSection>(
          find.byType(CategoryGroupSection),
        );
        expect(section.crossAxisCount, width < 600 ? 3 : 5);
        expect(
          find.byType(CategoryChoiceChip),
          findsNWidgets(width < 600 ? 9 : 25),
        );
        final target = find.byType(CategoryGroupSection);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final expand = find.textContaining('Lihat semua');
        await tester.ensureVisible(expand);
        await tester.pumpAndSettle();
        await tester.tap(expand);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

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
  ThemeData? theme,
  double width = 420,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1100);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
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
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
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
  int categoryId = 1,
}) => TransactionEntry(
  id: 7,
  type: type.value,
  amount: amount,
  categoryId: categoryId,
  walletId: 1,
  date: _now,
  createdAt: _now,
  updatedAt: _now,
);

class _TestStore implements FinanceStore {
  _TestStore({required int initialBalance, List<CategoryEntry>? categories})
    : walletsDao = _Wallets(initialBalance),
      categoriesDao = _Categories(categories);

  @override
  final _Wallets walletsDao;
  @override
  final _Transactions transactionsDao = _Transactions();
  @override
  final _Categories categoriesDao;

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
  _Categories([List<CategoryEntry>? categories])
    : entries =
          categories ??
          [
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
          ];

  final List<CategoryEntry> entries;

  @override
  Stream<List<CategoryEntry>> watchAll() => Stream.value(entries);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<CategoryEntry> _gridCategories() => [
  for (var id = 1; id <= 12; id++)
    CategoryEntry(
      id: id,
      name: id == 1
          ? 'Makanan & Minuman'
          : id == 12
          ? 'Kategori khusus dengan nama panjang'
          : 'Kategori $id',
      type: id == 1 ? 'both' : 'expense',
      groupName: 'Kebutuhan Harian',
      iconKey: id == 12 ? 'transport' : 'food',
      colorValue: 0xff2563eb,
      isDefault: false,
      isArchived: false,
      createdAt: _now,
      updatedAt: _now,
    ),
  for (final id in [20, 21])
    CategoryEntry(
      id: id,
      name: id == 20 ? 'Gaji' : 'Nonaktif',
      type: id == 20 ? 'income' : 'both',
      groupName: 'Penghasilan',
      iconKey: 'salary',
      colorValue: 0xff0369a1,
      isDefault: false,
      isArchived: id == 21,
      createdAt: _now,
      updatedAt: _now,
    ),
];
