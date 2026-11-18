import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:dompet_sheva/app/app.dart';
import 'package:dompet_sheva/app/providers/auth_providers.dart';
import 'package:dompet_sheva/data/auth/auth_repository.dart';
import 'package:dompet_sheva/features/auth/login_page.dart';

class _Auth extends Fake implements FirebaseAuth {
  final credentials = <AuthCredential>[];
  bool signedOut = false;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    credentials.add(credential);
    return _Credential();
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  Stream<User?> authStateChanges() => Stream.value(null);
}

class _Credential extends Fake implements UserCredential {}

class _Google implements NativeGoogleLogin {
  final prepared = Completer<void>();
  Object? failure;
  bool signedOut = false;
  @override
  Future<void> prepare() => prepared.future;
  @override
  Future<String> idToken() async {
    if (failure != null) throw failure!;
    return 'native-google-id-token';
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  test(
    'native login waits for initialization then exchanges Google ID token with Firebase',
    () async {
      final auth = _Auth();
      final google = _Google();
      final repository = FirebaseAuthRepository(
        auth: auth,
        isWeb: false,
        nativeGoogle: google,
      );
      final preparing = repository.prepareGoogleSignIn(trusted: true);
      expect(
        () => repository.signInWithGoogle(trusted: true),
        throwsA(isA<FirebaseAuthException>()),
      );
      google.prepared.complete();
      await preparing;
      await repository.signInWithGoogle(trusted: true);
      final credential = auth.credentials.single as OAuthCredential;
      expect(credential.providerId, 'google.com');
      expect(credential.idToken, 'native-google-id-token');
      await repository.signOut();
      expect(auth.signedOut && google.signedOut, isTrue);
    },
  );

  test(
    'cancelled native Google chooser never authenticates Firebase',
    () async {
      final auth = _Auth();
      final google = _Google()..prepared.complete();
      google.failure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      final repository = FirebaseAuthRepository(
        auth: auth,
        isWeb: false,
        nativeGoogle: google,
      );
      await repository.prepareGoogleSignIn(trusted: true);
      await expectLater(
        repository.signInWithGoogle(trusted: true),
        throwsA(isA<GoogleSignInException>()),
      );
      expect(auth.credentials, isEmpty);
      expect(authErrorMessage(google.failure!), contains('dibatalkan'));
    },
  );

  testWidgets(
    'Android checks authentication and shows native login without browser storage controls',
    (tester) async {
      final google = _Google()..prepared.complete();
      final repository = FirebaseAuthRepository(
        auth: _Auth(),
        isWeb: false,
        nativeGoogle: google,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            webPlatformProvider.overrideWithValue(false),
            authRepositoryProvider.overrideWithValue(repository),
          ],
          child: const DompetShevaApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(FinanceApp), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('Masuk dengan Google'), findsOneWidget);
      expect(find.textContaining('Data keuangan disinkronkan'), findsOneWidget);
    },
  );
}
