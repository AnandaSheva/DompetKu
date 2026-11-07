import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/app/app.dart';
import 'package:dompet_sheva/app/providers/auth_providers.dart';
import 'package:dompet_sheva/data/auth/auth_repository.dart';
import 'package:dompet_sheva/features/auth/login_page.dart';

class FakeAuth implements AuthRepository {
  final session = StreamController<AppAccount?>.broadcast();
  Completer<void>? login;
  Completer<void>? preparation;
  bool? preparedTrusted;
  bool? trusted;
  @override
  Stream<AppAccount?> authStateChanges() => session.stream;
  @override
  Future<void> prepareGoogleSignIn({required bool trusted}) {
    preparedTrusted = trusted;
    return preparation?.future ?? Future.value();
  }

  @override
  Future<void> signInWithGoogle({required bool trusted}) {
    this.trusted = trusted;
    return (login = Completer<void>()).future;
  }

  @override
  Future<void> signOut() async => session.add(null);
}

void main() {
  testWidgets('waits for session storage before enabling Google login', (
    tester,
  ) async {
    final auth = FakeAuth()..preparation = Completer<void>();
    addTearDown(auth.session.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    expect(auth.preparedTrusted, false);
    expect(find.text('Menyiapkan login...'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    expect(auth.login, isNull);

    auth.preparation!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Masuk dengan Google'), findsOneWidget);

    auth.preparation = Completer<void>();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(auth.preparedTrusted, true);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    auth.preparation!.complete();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Masuk dengan Google'));
    await tester.tap(find.text('Masuk dengan Google'));
    expect(auth.trusted, true);
    auth.login!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('retries a failed session preparation without opening Google', (
    tester,
  ) async {
    final auth = FakeAuth()..preparation = Completer<void>();
    addTearDown(auth.session.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    auth.preparation!.completeError(
      FirebaseAuthException(code: 'web-storage-unsupported'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Izinkan penyimpanan situs'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(auth.login, isNull);

    auth.preparation = null;
    await tester.ensureVisible(find.text('Coba lagi'));
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Coba lagi'), findsNothing);
    expect(find.textContaining('Izinkan penyimpanan situs'), findsNothing);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('checks session before showing Google login', (tester) async {
    final auth = FakeAuth();
    addTearDown(auth.session.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webPlatformProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: const DompetShevaApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Memeriksa sesi akun'), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsNothing);
    auth.session.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsOneWidget);
  });

  testWidgets('disables duplicate login and reports popup cancellation', (
    tester,
  ) async {
    final auth = FakeAuth();
    addTearDown(auth.session.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk dengan Google'));
    await tester.pump();
    expect(auth.trusted, false);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    auth.login!.completeError(
      FirebaseAuthException(code: 'popup-closed-by-user'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Login dibatalkan. Silakan coba lagi.'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('Masuk dengan Google'));
    await tester.tap(find.text('Masuk dengan Google'));
    expect(auth.trusted, true);
    auth.login!.complete();
    await tester.pumpAndSettle();
  });
}
