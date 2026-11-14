import 'package:drift/drift.dart' show Value;

import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/store/finance_store.dart';

Future<({int foodId, int drinkId})> seedLegacyFoodFixture(
  FinanceStore store, {
  int transactionCount = 2,
}) async {
  final food = (await store.categoriesDao.getAll()).singleWhere(
    (category) => category.name == 'Makanan & Minuman',
  );
  await store.categoriesDao.updateEntry(
    food.copyWith(name: 'Makanan').toCompanion(true),
  );
  final drinkId = await store.categoriesDao.add(
    food
        .copyWith(id: 10001, name: 'Minuman', iconKey: 'drink')
        .toCompanion(true),
  );
  final wallet = (await store.walletsDao.getAll()).first;
  final now = DateTime(2026, 11, 14, 12);
  for (var offset = 0; offset < transactionCount; offset += 400) {
    await store.transaction(() async {
      for (
        var index = offset;
        index < transactionCount && index < offset + 400;
        index++
      ) {
        await store.transactionsDao.add(
          TransactionEntriesCompanion.insert(
            type: 'expense',
            amount: index == 0 ? 18000 : 5000,
            categoryId: Value(index == 0 ? food.id : drinkId),
            walletId: wallet.id,
            date: now,
            note: Value('Catatan $index'),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
  }
  for (final (categoryId, month, amount) in [
    (food.id, '2026-11', 100000),
    (drinkId, '2026-11', 50000),
    (drinkId, '2026-10', 40000),
    (null, '2026-11', 700000),
  ]) {
    await store.budgetsDao.add(
      BudgetEntriesCompanion.insert(
        categoryId: Value(categoryId),
        month: month,
        limitAmount: amount,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
  await store.seedDao.insertQuickTemplates([
    QuickTemplateEntriesCompanion.insert(
      title: 'Kopi pagi',
      transactionType: 'expense',
      defaultAmount: const Value(5000),
      categoryId: Value(drinkId),
      walletId: Value(wallet.id),
      iconKey: 'drink',
      colorValue: food.colorValue,
      createdAt: now,
      updatedAt: now,
    ),
  ]);
  await store.recurringBillsDao.add(
    RecurringBillEntriesCompanion.insert(
      title: 'Air minum',
      amount: 40000,
      categoryId: drinkId,
      walletId: wallet.id,
      nextDueDate: DateTime(2026, 11, 30),
      frequency: 'monthly',
      anchorDay: 30,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return (foodId: food.id, drinkId: drinkId);
}
