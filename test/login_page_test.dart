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
  bool? trusted;
  @override
  Stream<AppAccount?> authStateChanges() => session.stream;
  @override
  Future<void> signInWithGoogle({required bool trusted}) {
    this.trusted = trusted;
    return (login = Completer<void>()).future;
  }

  @override
  Future<void> signOut() async => session.add(null);
}

void main() {
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
