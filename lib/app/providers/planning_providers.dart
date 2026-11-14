import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database/app_database.dart';
import '../../data/repositories/planning_repository.dart';
import 'app_providers.dart';

final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  return PlanningRepository(ref.watch(databaseProvider));
}, dependencies: [databaseProvider]);

final recurringBillsProvider = StreamProvider<List<RecurringBillEntry>>((ref) {
  return ref.watch(planningRepositoryProvider).watchBills();
}, dependencies: [planningRepositoryProvider]);

final savingsGoalsProvider = StreamProvider<List<SavingsGoalEntry>>((ref) {
  return ref.watch(planningRepositoryProvider).watchGoals();
}, dependencies: [planningRepositoryProvider]);
