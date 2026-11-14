import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/core/enums/category_type.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/bootstrap_repository.dart';
import 'package:dompet_sheva/data/repositories/category_repository.dart';

void main() {
  late AppDatabase database;
  late CategoryRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = CategoryRepository(database);
    await BootstrapRepository(database).ensureSeeded();
    await repository.addCategory(
      name: 'Kategori Uji',
      type: CategoryType.expense,
      groupName: 'Pengujian',
      colorValue: 0xff2563eb,
    );
  });
  tearDown(() => database.close());

  Future<CategoryEntry> customCategory() async =>
      (await database.categoriesDao.getAll()).singleWhere(
        (category) => !category.isDefault,
      );

  Future<void> addBudget(int categoryId) async {
    final now = DateTime(2026, 11, 14);
    await database.budgetsDao.add(
      BudgetEntriesCompanion.insert(
        categoryId: Value(categoryId),
        month: '2026-11',
        limitAmount: 100000,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> addTemplate(int categoryId) async {
    final now = DateTime(2026, 11, 14);
    await database.seedDao.insertQuickTemplates([
      QuickTemplateEntriesCompanion.insert(
        title: 'Template Uji',
        transactionType: 'expense',
        categoryId: Value(categoryId),
        iconKey: 'category',
        colorValue: 0xff2563eb,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  test(
    'deletes an unused custom category without changing other records',
    () async {
      final custom = await customCategory();
      final other = (await database.categoriesDao.getByType('expense')).first;
      await addBudget(other.id);
      await addTemplate(other.id);

      expect(await repository.deleteCategory(custom), isNull);
      expect(
        (await database.categoriesDao.getAll()).any(
          (row) => row.id == custom.id,
        ),
        false,
      );
      expect((await database.budgetsDao.getAll()).single.categoryId, other.id);
      expect((await database.getQuickTemplates()).single.categoryId, other.id);
    },
  );

  test('keeps default categories and explains how to hide them', () async {
    final category = (await database.categoriesDao.getAll()).first;

    expect(
      await repository.deleteCategory(category),
      'Kategori bawaan tidak bisa dihapus. Gunakan Nonaktifkan.',
    );
    expect(await database.categoriesDao.getAll(), contains(category));
  });

  test(
    'keeps categories used by transactions and preserves their history',
    () async {
      final custom = await customCategory();
      final wallet = (await database.walletsDao.getAll()).first;
      final now = DateTime(2026, 11, 14);
      await database.transactionsDao.add(
        TransactionEntriesCompanion.insert(
          type: 'expense',
          amount: 10000,
          categoryId: Value(custom.id),
          walletId: wallet.id,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final transaction = (await database.transactionsDao.getAll()).single;

      expect(
        await repository.deleteCategory(custom),
        'Kategori masih dipakai transaksi. Gunakan Nonaktifkan.',
      );
      expect(await database.categoriesDao.getAll(), contains(custom));
      expect((await database.transactionsDao.getAll()).single, transaction);
    },
  );

  test(
    'keeps categories used by a budget and returns an actionable message',
    () async {
      final custom = await customCategory();
      await addBudget(custom.id);

      expect(
        await repository.deleteCategory(custom),
        'Kategori masih dipakai budget. Gunakan Nonaktifkan.',
      );
      expect(await database.categoriesDao.getAll(), contains(custom));
      expect((await database.budgetsDao.getAll()).single.categoryId, custom.id);
    },
  );

  test('keeps categories used by a quick template', () async {
    final custom = await customCategory();
    await addTemplate(custom.id);

    expect(
      await repository.deleteCategory(custom),
      'Kategori masih dipakai template. Gunakan Nonaktifkan.',
    );
    expect(await database.categoriesDao.getAll(), contains(custom));
    expect((await database.getQuickTemplates()).single.categoryId, custom.id);
  });
}
