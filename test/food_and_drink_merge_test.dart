import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/backup_repository.dart';
import 'package:dompet_sheva/data/repositories/bootstrap_repository.dart';
import 'package:dompet_sheva/data/repositories/budget_repository.dart';

import 'helpers/legacy_food_fixture.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await BootstrapRepository(database).ensureSeeded();
  });
  tearDown(() => database.close());

  Future<Map<String, dynamic>> snapshot() async =>
      (await BackupRepository(database).exportPayload())..remove('exported_at');

  test(
    'new installs have one food and drink category with the original food ID',
    () async {
      final categories = await database.categoriesDao.getAll();
      final food = categories.singleWhere(
        (category) => category.name == 'Makanan & Minuman',
      );
      expect(food.id, 1);
      expect(food.iconKey, 'food');
      expect(
        categories.where((category) => category.name == 'Makanan'),
        isEmpty,
      );
      expect(
        categories.where((category) => category.name == 'Minuman'),
        isEmpty,
      );
    },
  );

  test(
    'startup keeps the Makanan ID and moves every reference before deleting Minuman',
    () async {
      final legacy = await seedLegacyFoodFixture(database);
      final before = await database.transactionsDao.getAll();
      final budgets = await database.budgetsDao.getAll();
      final foodBudget = budgets.singleWhere(
        (row) => row.categoryId == legacy.foodId,
      );
      final drinkOnlyBudget = budgets.singleWhere(
        (row) => row.month == '2026-10',
      );
      final template = (await database.getQuickTemplates()).single;
      final bill = (await database.recurringBillsDao.getAll()).single;

      await BootstrapRepository(database).ensureSeeded();

      final categories = await database.categoriesDao.getAll();
      expect(categories.any((row) => row.id == legacy.drinkId), false);
      expect(
        categories.singleWhere((row) => row.id == legacy.foodId).name,
        'Makanan & Minuman',
      );
      final transactions = await database.transactionsDao.getAll();
      for (final original in before) {
        final updated = transactions.singleWhere(
          (row) => row.id == original.id,
        );
        expect(updated.categoryId, legacy.foodId);
        expect(updated.amount, original.amount);
        expect(updated.note, original.note);
        expect(updated.date, original.date);
        expect(updated.walletId, original.walletId);
        expect(updated.createdAt, original.createdAt);
      }
      final remainingBudgets = await database.budgetsDao.getAll();
      expect(remainingBudgets, hasLength(3));
      final combined = remainingBudgets.singleWhere(
        (row) => row.id == foodBudget.id,
      );
      expect(combined.categoryId, legacy.foodId);
      expect(combined.limitAmount, 150000);
      expect(combined.createdAt, foodBudget.createdAt);
      final moved = remainingBudgets.singleWhere(
        (row) => row.id == drinkOnlyBudget.id,
      );
      expect(moved.categoryId, legacy.foodId);
      expect(moved.limitAmount, 40000);
      expect(
        remainingBudgets
            .singleWhere((row) => row.categoryId == null)
            .limitAmount,
        700000,
      );
      final progress = await BudgetRepository(database).getProgress();
      expect(
        progress.singleWhere((row) => row.budget.id == foodBudget.id).spent,
        23000,
      );
      final updatedTemplate = (await database.getQuickTemplates()).single;
      expect(updatedTemplate.id, template.id);
      expect(updatedTemplate.categoryId, legacy.foodId);
      expect(updatedTemplate.defaultAmount, template.defaultAmount);
      final updatedBill = (await database.recurringBillsDao.getAll()).single;
      expect(updatedBill.id, bill.id);
      expect(updatedBill.categoryId, legacy.foodId);
      expect(updatedBill.amount, bill.amount);
      expect(updatedBill.nextDueDate, bill.nextDueDate);
    },
  );

  test('restarting the migration does not add budget limits twice', () async {
    await seedLegacyFoodFixture(database);
    await database.categoriesDao.mergeFoodAndDrink();
    final merged = await snapshot();

    await BootstrapRepository(database).ensureSeeded();
    await database.categoriesDao.mergeFoodAndDrink();

    expect(await snapshot(), merged);
  });

  test(
    'a storage failure rolls back category, budget and reference changes together',
    () async {
      final legacy = await seedLegacyFoodFixture(database);
      final before = await snapshot();
      await database.customStatement('''
      CREATE TRIGGER prevent_drink_delete BEFORE DELETE ON categories
      WHEN OLD.id = ${legacy.drinkId}
      BEGIN SELECT RAISE(ABORT, 'Simulated migration failure'); END
    ''');

      await expectLater(
        database.categoriesDao.mergeFoodAndDrink(),
        throwsA(isA<SqliteException>()),
      );

      expect(await snapshot(), before);
      await database.customStatement('DROP TRIGGER prevent_drink_delete');
      await database.categoriesDao.mergeFoodAndDrink();
      expect(
        (await database.categoriesDao.getAll()).any(
          (row) => row.id == legacy.drinkId,
        ),
        false,
      );
    },
  );

  test(
    'restoring a legacy backup also consolidates its categories and keeps IDs',
    () async {
      final legacy = await seedLegacyFoodFixture(database);
      final backup = BackupRepository(database);
      final preview = backup.previewFromJson(
        jsonEncode(await backup.exportPayload()),
      );

      await backup.restoreImport(preview);

      final categories = await database.categoriesDao.getAll();
      expect(
        categories.singleWhere((row) => row.id == legacy.foodId).name,
        'Makanan & Minuman',
      );
      expect(categories.any((row) => row.id == legacy.drinkId), false);
      expect(
        (await database.transactionsDao.getAll()).map((row) => row.categoryId),
        everyElement(legacy.foodId),
      );
    },
  );

  test(
    'custom categories and deliberately renamed defaults are preserved',
    () async {
      final legacy = await seedLegacyFoodFixture(database);
      final food = (await database.categoriesDao.getAll()).singleWhere(
        (row) => row.id == legacy.foodId,
      );
      await database.categoriesDao.updateEntry(
        food.copyWith(name: 'Jajan').toCompanion(true),
      );
      await database.categoriesDao.add(
        food
            .copyWith(id: 10002, name: 'Makanan', isDefault: false)
            .toCompanion(true),
      );
      final before = await snapshot();

      await database.categoriesDao.mergeFoodAndDrink();

      expect(await snapshot(), before);
    },
  );
}
