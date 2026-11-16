import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/financial_calendar.dart';
import 'app_providers.dart';
import 'planning_providers.dart';

// Reuse the account-scoped shared streams. Changing month adds no store listener.
final financialCalendarProvider = Provider.autoDispose
    .family<AsyncValue<FinancialCalendarMonth>, DateTime>((ref, month) {
      final transactions = ref.watch(transactionDetailsProvider);
      final bills = ref.watch(recurringBillsProvider);
      if (transactions.hasError) {
        return AsyncError(transactions.error!, transactions.stackTrace!);
      }
      if (bills.hasError) {
        return AsyncError(bills.error!, bills.stackTrace!);
      }
      if (transactions.isLoading || bills.isLoading) {
        return const AsyncLoading();
      }
      return AsyncData(
        FinancialCalendarMonth.fromData(
          month: month,
          transactions: transactions.requireValue,
          bills: bills.requireValue,
        ),
      );
    }, dependencies: [transactionDetailsProvider, recurringBillsProvider]);
