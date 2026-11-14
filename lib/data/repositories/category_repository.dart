import 'package:drift/drift.dart';

import '../../core/enums/category_type.dart';
import '../local/database/app_database.dart';
import '../store/finance_store.dart';

class CategoryRepository {
  const CategoryRepository(this._database);

  final FinanceStore _database;

  Stream<List<CategoryEntry>> watchAll() {
    return _database.categoriesDao.watchAll();
  }

  Future<List<CategoryEntry>> getByTransactionType(String type) {
    return _database.categoriesDao.getByType(type);
  }

  Future<void> addCategory({
    required String name,
    required CategoryType type,
    required String groupName,
    required int colorValue,
  }) async {
    final trimmedName = name.trim();
    final trimmedGroup = groupName.trim().isEmpty
        ? 'Lainnya'
        : groupName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Nama kategori belum diisi.');
    }
    final duplicateCount = await _database.categoriesDao.countDuplicate(
      name: trimmedName,
      type: type.value,
      groupName: trimmedGroup,
    );
    if (duplicateCount > 0) {
      throw ArgumentError('Kategori sudah ada di grup ini.');
    }
    final now = DateTime.now();
    await _database.categoriesDao.add(
      CategoryEntriesCompanion.insert(
        name: trimmedName,
        type: type.value,
        groupName: trimmedGroup,
        iconKey: 'category',
        colorValue: colorValue,
        isDefault: const Value(false),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateCategory({
    required CategoryEntry category,
    required String name,
    required CategoryType type,
    required String groupName,
    required int colorValue,
  }) async {
    final trimmedName = name.trim();
    final trimmedGroup = groupName.trim().isEmpty
        ? 'Lainnya'
        : groupName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Nama kategori belum diisi.');
    }
    final duplicateCount = await _database.categoriesDao.countDuplicate(
      name: trimmedName,
      type: type.value,
      groupName: trimmedGroup,
      exceptId: category.id,
    );
    if (duplicateCount > 0) {
      throw ArgumentError('Kategori sudah ada di grup ini.');
    }
    await _database.categoriesDao.updateEntry(
      category
          .copyWith(
            name: trimmedName,
            type: type.value,
            groupName: trimmedGroup,
            colorValue: colorValue,
            updatedAt: DateTime.now(),
          )
          .toCompanion(true),
    );
  }

  Future<String?> deleteCategory(CategoryEntry category) async {
    final count = await _database.transactionsDao.countByCategory(category.id);
    if (count > 0) {
      return 'Kategori masih dipakai transaksi. Gunakan Nonaktifkan.';
    }
    if (category.isDefault) {
      return 'Kategori bawaan tidak bisa dihapus. Gunakan Nonaktifkan.';
    }
    final budgets = await _database.budgetsDao.getAll();
    if (budgets.any((budget) => budget.categoryId == category.id)) {
      return 'Kategori masih dipakai budget. Gunakan Nonaktifkan.';
    }
    final templates = await _database.getQuickTemplates();
    if (templates.any((template) => template.categoryId == category.id)) {
      return 'Kategori masih dipakai template. Gunakan Nonaktifkan.';
    }

    await _database.categoriesDao.deleteById(category.id);
    return null;
  }

  Future<void> setArchived(CategoryEntry category, bool value) async {
    await _database.categoriesDao.updateEntry(
      category
          .copyWith(isArchived: value, updatedAt: DateTime.now())
          .toCompanion(true),
    );
  }
}
