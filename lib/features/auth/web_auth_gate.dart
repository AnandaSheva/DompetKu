import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/providers/app_providers.dart';
import '../../app/providers/auth_providers.dart';
import '../../app/theme/app_theme.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/auth/browser_session.dart';
import '../../data/store/cloud_finance_store.dart';
import '../../shared/widgets/loading_state.dart';
import 'login_page.dart';

bool _firestoreConfigured = false;

class WebAuthGate extends ConsumerWidget {
  const WebAuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionClosingProvider)) {
      return _frame(const LoadingState(message: 'Mengakhiri sesi dengan aman'));
    }
    return ref
        .watch(authStateProvider)
        .when(
          data: (account) {
            // Keep the app's original isolation headers for reading legacy Drift
            // OPFS data, and run the OAuth popup on a separate same-origin route.
            if (kIsWeb && account == null && !isLoginRoute) {
              openLoginRoute();
              return _frame(
                const LoadingState(message: 'Menyiapkan halaman masuk'),
              );
            }
            if (kIsWeb && account != null && isLoginRoute) {
              openAccountRoute();
              return _frame(
                const LoadingState(message: 'Menyiapkan data akun'),
              );
            }
            return account == null
                ? _frame(const LoginPage())
                : _AccountSession(key: ValueKey(account.uid), account: account);
          },
          loading: () =>
              _frame(const LoadingState(message: 'Memeriksa sesi akun')),
          error: (_, _) => _frame(
            Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Sesi akun belum bisa diperiksa.'),
                    TextButton(
                      onPressed: () => ref.invalidate(authStateProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }

  Widget _frame(Widget home) => MaterialApp(
    title: 'DompetKu',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: home,
  );
}

class _AccountSession extends StatefulWidget {
  const _AccountSession({super.key, required this.account});
  final AppAccount account;
  @override
  State<_AccountSession> createState() => _AccountSessionState();
}

class _AccountSessionState extends State<_AccountSession> {
  late final CloudFinanceStore _store;
  @override
  void initState() {
    super.initState();
    final firestore = FirebaseFirestore.instance;
    if (!_firestoreConfigured) {
      firestore.settings = Settings(persistenceEnabled: trustedDevice);
      _firestoreConfigured = true;
    }
    _store = CloudFinanceStore(firestore, widget.account.uid);
  }

  @override
  void dispose() {
    unawaited(_store.close());
    warnBeforeLeaving(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      currentAccountProvider.overrideWithValue(widget.account),
      cloudStoreProvider.overrideWithValue(_store),
      databaseProvider.overrideWithValue(_store),
      appBootstrapProvider.overrideWith((ref) => _store.initialize()),
    ],
    child: const FinanceApp(),
  );
}
