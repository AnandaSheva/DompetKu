import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/app/theme/app_theme.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/app_models.dart';
import 'package:dompet_sheva/data/repositories/wallet_repository.dart';
import 'package:dompet_sheva/data/store/finance_store.dart';
import 'package:dompet_sheva/features/wallets/wallets_page.dart';
import 'package:dompet_sheva/shared/widgets/top_toast.dart';

final _now = DateTime(2026, 11, 17);
final _bank = WalletEntry(
  id: 1,
  name: 'BRI',
  type: 'bank',
  initialBalance: 400000,
  reservedBalance: 50000,
  isArchived: false,
  createdAt: _now,
  updatedAt: _now,
);

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  tearDown(TopToast.dismiss);

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'bank form saves its reserve in ${theme.brightness.name} theme',
      (tester) async {
        final repository = _WalletRepository();
        await _pump(tester, repository, theme: theme);
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();
        expect(_field('Saldo endapan'), findsNothing);
        await tester.enterText(_field('Nama dompet'), 'BCA');
        await tester.tap(find.widgetWithText(ChoiceChip, 'Rekening'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(_field('Saldo awal'));
        await tester.enterText(_field('Saldo awal'), '200000');
        await tester.ensureVisible(_field('Saldo endapan'));
        await tester.enterText(_field('Saldo endapan'), '25000');
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();
        expect(repository.savedName, 'BCA');
        expect(repository.savedType, 'bank');
        expect(repository.savedInitialBalance, 200000);
        expect(repository.savedReserve, 25000);
        expect(tester.takeException(), isNull);
        TopToast.dismiss();
      },
    );
  }

  testWidgets('editing a bank loads and updates its own reserve', (
    tester,
  ) async {
    final repository = _WalletRepository();
    await _pump(tester, repository);
    expect(find.text('Rp350.000'), findsOneWidget);
    await tester.tap(find.text('BRI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_field('Saldo endapan')).controller!.text,
      'Rp50.000',
    );
    await tester.ensureVisible(_field('Saldo endapan'));
    await tester.enterText(_field('Saldo endapan'), '75000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(repository.savedId, _bank.id);
    expect(repository.savedReserve, 75000);
    expect(repository.savedInitialBalance, 400000);
    TopToast.dismiss();
  });

  testWidgets('changing a bank to another type clears the reserve', (
    tester,
  ) async {
    final repository = _WalletRepository();
    await _pump(tester, repository);
    await tester.tap(find.text('BRI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tunai'));
    await tester.pumpAndSettle();
    expect(_field('Saldo endapan'), findsNothing);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(repository.savedType, 'cash');
    expect(repository.savedReserve, 0);
    TopToast.dismiss();
  });

  testWidgets(
    'hidden balances also hide reserves and available money in details',
    (tester) async {
      await _pump(tester, _WalletRepository(), hideBalance: true);
      await tester.tap(find.text('BRI'));
      await tester.pumpAndSettle();
      for (final amount in ['Rp400.000', 'Rp50.000', 'Rp350.000']) {
        expect(find.text(amount), findsNothing);
      }
      expect(find.text('Saldo endapan'), findsWidgets);
      expect(find.text('Bisa dipakai'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  _WalletRepository repository, {
  ThemeData? theme,
  bool hideBalance = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 780);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        walletRepositoryProvider.overrideWithValue(repository),
        walletBalancesProvider.overrideWith(
          (ref) =>
              Stream.value([WalletBalance(wallet: _bank, balance: 400000)]),
        ),
        appSettingsProvider.overrideWith(
          (ref) => Stream.value(
            AppSettingEntry(
              id: 1,
              currency: 'IDR',
              themeMode: 'system',
              hideBalance: hideBalance,
              onboardingCompleted: true,
              monthlyResetDay: 1,
              createdAt: _now,
              updatedAt: _now,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.2)),
          child: child!,
        ),
        home: const Scaffold(body: WalletsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _WalletRepository extends WalletRepository {
  _WalletRepository() : super(_UnusedStore());
  int? savedId, savedInitialBalance, savedReserve;
  String? savedName, savedType;

  @override
  Future<int> transactionCount(int walletId) async => 0;

  @override
  Future<void> addWallet({
    required String name,
    required String type,
    int initialBalance = 0,
    int reservedBalance = 0,
  }) async {
    savedName = name;
    savedType = type;
    savedInitialBalance = initialBalance;
    savedReserve = reservedBalance;
  }

  @override
  Future<void> updateWallet({
    required WalletEntry wallet,
    required String name,
    required String type,
    required int initialBalance,
    int? reservedBalance,
  }) async {
    savedId = wallet.id;
    await addWallet(
      name: name,
      type: type,
      initialBalance: initialBalance,
      reservedBalance: reservedBalance ?? wallet.reservedBalance,
    );
  }
}

class _UnusedStore implements FinanceStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
