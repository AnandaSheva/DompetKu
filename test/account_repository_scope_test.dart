import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';

void main() {
  test(
    'account-scoped storage does not share repository data with another scope',
    () async {
      final parent = ProviderContainer();
      final aliceDb = AppDatabase(NativeDatabase.memory());
      final bobDb = AppDatabase(NativeDatabase.memory());
      final alice = ProviderContainer(
        parent: parent,
        overrides: [databaseProvider.overrideWithValue(aliceDb)],
      );
      final bob = ProviderContainer(
        parent: parent,
        overrides: [databaseProvider.overrideWithValue(bobDb)],
      );
      addTearDown(() async {
        alice.dispose();
        bob.dispose();
        parent.dispose();
        await aliceDb.close();
        await bobDb.close();
      });
      await alice.read(appBootstrapProvider.future);
      await bob.read(appBootstrapProvider.future);
      await alice
          .read(settingsRepositoryProvider)
          .completeOnboarding(userName: 'Alice');
      expect(
        (await alice.read(settingsRepositoryProvider).getSettings())?.userName,
        'Alice',
      );
      expect(
        (await bob.read(settingsRepositoryProvider).getSettings())?.userName,
        isNull,
      );
      await alice
          .read(walletRepositoryProvider)
          .addWallet(name: 'Dompet Alice', type: 'cash');
      expect(
        await alice.read(walletRepositoryProvider).getWallets(),
        hasLength(5),
      );
      expect(
        await bob.read(walletRepositoryProvider).getWallets(),
        hasLength(4),
      );
    },
  );
}
