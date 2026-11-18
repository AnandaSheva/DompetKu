import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_repository.dart';
import '../../data/store/cloud_finance_store.dart';

final webPlatformProvider = Provider<bool>((ref) => kIsWeb);
final accountPlatformProvider = Provider<bool>(
  (ref) =>
      ref.watch(webPlatformProvider) ||
      defaultTargetPlatform == TargetPlatform.android,
);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(isWeb: ref.watch(webPlatformProvider)),
);
final authStateProvider = StreamProvider<AppAccount?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
final currentAccountProvider = Provider<AppAccount?>(
  (ref) => null,
  dependencies: [],
);
final cloudStoreProvider = Provider<CloudFinanceStore?>(
  (ref) => null,
  dependencies: [],
);
final cloudStatusProvider = StreamProvider<CloudStatus>((ref) {
  final store = ref.watch(cloudStoreProvider);
  return store?.statuses ?? const Stream.empty();
}, dependencies: [cloudStoreProvider]);

class SessionClosing extends Notifier<bool> {
  @override
  bool build() => false;
  void setClosing(bool value) => state = value;
}

final sessionClosingProvider = NotifierProvider<SessionClosing, bool>(
  SessionClosing.new,
);
