import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/app/theme/app_theme.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/app_models.dart';
import 'package:dompet_sheva/features/transactions/transactions_page.dart';
import 'package:dompet_sheva/features/transactions/widgets/transaction_tile.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final deletedSource in [true, false]) {
      testWidgets(
        'transfer log is read only with ${deletedSource ? 'source' : 'destination'} deleted in ${theme.brightness.name}',
        (tester) async {
          final now = DateTime.now();
          final wallet = WalletEntry(
            id: 1,
            name: 'Rekening lama',
            type: 'bank',
            initialBalance: 0,
            reservedBalance: 0,
            isArchived: deletedSource,
            deletedAt: deletedSource ? now : null,
            createdAt: now,
            updatedAt: now,
          );
          final destination = wallet.copyWith(
            id: 2,
            name: 'Tunai',
            type: 'cash',
            isArchived: !deletedSource,
            deletedAt: Value(deletedSource ? null : now),
          );
          final detail = TransactionDetail(
            transaction: TransactionEntry(
              id: 1,
              type: 'transfer',
              amount: 10000,
              walletId: 1,
              transferWalletId: 2,
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
            wallet: wallet,
            transferWallet: destination,
          );
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                transactionDetailsProvider.overrideWith(
                  (ref) => Stream.value([detail]),
                ),
                appSettingsProvider.overrideWith((ref) => Stream.value(null)),
              ],
              child: MaterialApp(
                theme: theme,
                home: const Scaffold(body: TransactionsPage()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('Log dompet dihapus'), findsOneWidget);
          await tester.longPress(find.byType(TransactionTile));
          await tester.pumpAndSettle();
          expect(find.text('Hapus transaksi?'), findsNothing);
          expect(
            find.textContaining('Riwayat ini hanya bisa dibaca'),
            findsOneWidget,
          );
          Navigator.of(
            tester.element(
              find.textContaining('Riwayat ini hanya bisa dibaca'),
            ),
          ).pop();
          await tester.pumpAndSettle();
          await tester.tap(find.byType(TransactionTile));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Riwayat ini hanya bisa dibaca'),
            findsOneWidget,
          );
          expect(find.text('Edit'), findsNothing);
          expect(find.text('Hapus'), findsNothing);
          expect(find.text('Jadikan tagihan berulang'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
