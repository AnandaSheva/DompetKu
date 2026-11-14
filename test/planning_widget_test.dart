import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/app/providers/planning_providers.dart';
import 'package:dompet_sheva/app/theme/app_theme.dart';
import 'package:dompet_sheva/core/formatters/currency_formatter.dart';
import 'package:dompet_sheva/core/formatters/date_formatter.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/app_models.dart';
import 'package:dompet_sheva/data/repositories/planning_repository.dart';
import 'package:dompet_sheva/data/repositories/wallet_repository.dart';
import 'package:dompet_sheva/data/store/finance_store.dart';
import 'package:dompet_sheva/features/planning/planning_forms.dart';
import 'package:dompet_sheva/features/planning/planning_page.dart';
import 'package:dompet_sheva/shared/widgets/top_toast.dart';

final _now = DateTime.now();
final _wallet = WalletEntry(
  id: 1,
  name: 'Tunai',
  type: 'cash',
  initialBalance: 100,
  isArchived: false,
  createdAt: _now,
  updatedAt: _now,
);
final _category = CategoryEntry(
  id: 2,
  name: 'Internet',
  type: 'expense',
  groupName: 'Tagihan',
  iconKey: 'category',
  colorValue: 0xff2563eb,
  isDefault: false,
  isArchived: false,
  createdAt: _now,
  updatedAt: _now,
);
final _bill = RecurringBillEntry(
  id: 3,
  title: 'Internet rumah',
  amount: 1000,
  categoryId: 2,
  walletId: 1,
  nextDueDate: DateFormatter.startOfDay(_now),
  frequency: 'monthly',
  anchorDay: _now.day,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  tearDown(TopToast.dismiss);

  testWidgets(
    'requires payment confirmation and cancellation leaves bill unchanged',
    (tester) async {
      final repository = _PlanningRepository();
      await _pump(tester, repository);
      await tester.tap(find.text('Catat pembayaran'));
      await tester.pumpAndSettle();
      expect(find.text('Catat pembayaran?'), findsOneWidget);
      expect(find.textContaining('saldo menjadi negatif'), findsOneWidget);
      expect(repository.payments, 0);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repository.payments, 0);
      expect(find.text('Jatuh tempo hari ini'), findsOneWidget);
    },
  );

  testWidgets('confirms payment once and disables mutations while saving', (
    tester,
  ) async {
    final repository = _PlanningRepository()
      ..paymentCompleter = Completer<void>();
    await _pump(tester, repository);
    await tester.tap(find.text('Catat pembayaran'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Catat pembayaran'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.payments, 1);
    expect(repository.lastPaidDate, DateFormatter.startOfDay(_now));
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Catat pembayaran'),
    );
    expect(button.onPressed, isNull);
    repository.paymentCompleter!.complete();
    await tester.pumpAndSettle();
    expect(repository.payments, 1);
    TopToast.dismiss();
  });

  testWidgets(
    'target form explains manual tracking and preserves entered progress',
    (tester) async {
      final repository = _PlanningRepository();
      await _pump(tester, repository, page: const PlanningPage(initialTab: 1));
      await tester.tap(find.text('Tambah target tabungan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Progres dicatat manual dan tidak mengubah saldo dompet.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Dana darurat');
      await tester.enterText(find.byType(TextFormField).at(1), '10000000');
      await tester.enterText(find.byType(TextFormField).at(2), '2000000');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repository.savedGoalName, 'Dana darurat');
      expect(repository.savedTarget, 10000000);
      expect(repository.savedAmount, 2000000);
      expect(repository.payments, 0);
      TopToast.dismiss();
    },
  );

  testWidgets(
    'source expense pre-fills a future monthly bill without recording payment',
    (tester) async {
      final repository = _PlanningRepository();
      final source = TransactionEntry(
        id: 9,
        type: 'expense',
        amount: 123000,
        categoryId: 2,
        walletId: 1,
        date: DateTime(2024, 1, 31),
        createdAt: _now,
        updatedAt: _now,
      );
      await _pump(
        tester,
        repository,
        page: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showRecurringBillForm(context, sourceTransaction: source),
              child: const Text('Jadwalkan'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Jadwalkan'));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields.first.controller!.text, 'Internet');
      expect(fields[1].controller!.text, CurrencyFormatter.rupiah(123000));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repository.savedBillDue, isNotNull);
      expect(
        repository.savedBillDue!.isBefore(DateFormatter.startOfDay(_now)),
        isFalse,
      );
      expect(repository.payments, 0);
      TopToast.dismiss();
    },
  );

  testWidgets('invalid target remains in form without saving', (tester) async {
    final repository = _PlanningRepository();
    await _pump(tester, repository, page: const PlanningPage(initialTab: 1));
    await tester.tap(find.text('Tambah target tabungan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nama belum diisi.'), findsOneWidget);
    expect(find.text('Nominal harus lebih dari nol.'), findsOneWidget);
    expect(repository.savedGoalName, isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _PlanningRepository repository, {
  Widget page = const PlanningPage(),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        planningRepositoryProvider.overrideWithValue(repository),
        walletRepositoryProvider.overrideWithValue(_WalletRepository()),
        walletBalancesProvider.overrideWith(
          (ref) => Stream.value([WalletBalance(wallet: _wallet, balance: 100)]),
        ),
        categoriesProvider.overrideWith((ref) => Stream.value([_category])),
        appSettingsProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: page),
    ),
  );
  await tester.pumpAndSettle();
}

class _PlanningRepository extends PlanningRepository {
  _PlanningRepository() : super(_UnusedStore());
  int payments = 0;
  DateTime? lastPaidDate;
  DateTime? savedBillDue;
  String? savedGoalName;
  int? savedTarget, savedAmount;
  Completer<void>? paymentCompleter;

  @override
  Stream<List<RecurringBillEntry>> watchBills() => Stream.value([_bill]);
  @override
  Stream<List<SavingsGoalEntry>> watchGoals() => Stream.value([]);
  @override
  Future<void> payBill(RecurringBillEntry bill, {DateTime? paidAt}) async {
    payments++;
    lastPaidDate = paidAt;
    await paymentCompleter?.future;
  }

  @override
  Future<void> saveGoal({
    int? id,
    required String name,
    required int targetAmount,
    required int savedAmount,
    DateTime? targetDate,
  }) async {
    savedGoalName = name;
    savedTarget = targetAmount;
    this.savedAmount = savedAmount;
  }

  @override
  Future<void> saveBill({
    int? id,
    RecurringBillEntry? expectedBill,
    required String title,
    required int amount,
    required int categoryId,
    required int walletId,
    required DateTime nextDueDate,
    required String frequency,
    bool isActive = true,
    int? anchorDay,
  }) async {
    savedBillDue = nextDueDate;
  }
}

class _WalletRepository extends WalletRepository {
  _WalletRepository() : super(_UnusedStore());
  @override
  Future<WalletBalance?> getWalletBalance({
    required int walletId,
    int? excludingTransactionId,
  }) async => WalletBalance(wallet: _wallet, balance: 100);
}

class _UnusedStore implements FinanceStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected store access: ${invocation.memberName}',
  );
}
