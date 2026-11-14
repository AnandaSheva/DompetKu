import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';

/// Consolidates the shipped categories without changing user-created ones.
class FoodAndDrinkMerge {
  FoodAndDrinkMerge._(this.target, this.sourceIds);

  static const name = 'Makanan & Minuman';

  final CategoryEntry target;
  final Set<int> sourceIds;

  static FoodAndDrinkMerge? from(List<CategoryEntry> categories) {
    final defaults = categories.where(
      (category) =>
          category.isDefault &&
          category.type == 'expense' &&
          category.groupName == 'Kebutuhan Harian',
    );
    // Prefer the original Makanan ID even if a combined category already exists.
    final target =
        defaults.where((category) => category.name == 'Makanan').firstOrNull ??
        defaults.where((category) => category.name == name).firstOrNull;
    if (target == null) return null;
    final sources = defaults
        .where(
          (category) =>
              category.id != target.id &&
              (category.name == 'Minuman' || category.name == name),
        )
        .map((category) => category.id)
        .toSet();
    if (target.name == name && sources.isEmpty) return null;
    return FoodAndDrinkMerge._(target, sources);
  }

  Iterable<({BudgetEntry retained, List<int> removedIds})> budgets(
    List<BudgetEntry> entries,
    DateTime now,
  ) sync* {
    final byMonth = <String, List<BudgetEntry>>{};
    for (final entry in entries) {
      if (entry.categoryId == target.id ||
          sourceIds.contains(entry.categoryId)) {
        byMonth.putIfAbsent(entry.month, () => []).add(entry);
      }
    }
    for (final group in byMonth.values) {
      if (!group.any((entry) => sourceIds.contains(entry.categoryId))) continue;
      final retained =
          group.where((entry) => entry.categoryId == target.id).firstOrNull ??
          group.first;
      yield (
        retained: retained.copyWith(
          categoryId: Value(target.id),
          limitAmount: group.fold<int>(
            0,
            (sum, entry) => sum + entry.limitAmount,
          ),
          updatedAt: now,
        ),
        removedIds: [
          for (final entry in group)
            if (entry.id != retained.id) entry.id,
        ],
      );
    }
  }
}
