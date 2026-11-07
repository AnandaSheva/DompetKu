import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/data/auth/auth_repository.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  Completer<void>? persistence;
  final popup = Completer<UserCredential>();
  final persistenceRequests = <Persistence>[];
  final popupProviders = <AuthProvider>[];

  @override
  Future<void> setPersistence(Persistence persistence) {
    persistenceRequests.add(persistence);
    return this.persistence?.future ?? Future.value();
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) {
    popupProviders.add(provider);
    return popup.future;
  }
}

class _FakeCredential extends Fake implements UserCredential {}

void main() {
  for (final trusted in [false, true]) {
    test(
      'opens Google immediately after session preparation ($trusted)',
      () async {
        final auth = _FakeFirebaseAuth()..persistence = Completer<void>();
        final repository = FirebaseAuthRepository(auth: auth);

        final preparation = repository.prepareGoogleSignIn(trusted: trusted);
        expect(auth.persistenceRequests, [
          trusted ? Persistence.LOCAL : Persistence.SESSION,
        ]);
        expect(
          () => repository.signInWithGoogle(trusted: trusted),
          throwsA(isA<FirebaseAuthException>()),
        );
        expect(auth.popupProviders, isEmpty);

        auth.persistence!.complete();
        await preparation;
        final login = repository.signInWithGoogle(trusted: trusted);
        // This must happen in the tap's call stack, before any async turn.
        expect(auth.popupProviders, hasLength(1));
        final provider = auth.popupProviders.single as GoogleAuthProvider;
        expect(provider.parameters['prompt'], 'select_account');
        // Login must not change persistence or wait for storage again.
        expect(auth.persistenceRequests, hasLength(1));

        auth.popup.complete(_FakeCredential());
        await login;
      },
    );
  }

  test('never opens Google with a different device preference', () async {
    final auth = _FakeFirebaseAuth();
    final repository = FirebaseAuthRepository(auth: auth);
    await repository.prepareGoogleSignIn(trusted: true);

    expect(
      () => repository.signInWithGoogle(trusted: false),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(auth.popupProviders, isEmpty);
  });

  test(
    'failed persistence change blocks login until preparation succeeds',
    () async {
      final auth = _FakeFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      await repository.prepareGoogleSignIn(trusted: true);
      auth.persistence = Completer<void>();
      final preparation = repository.prepareGoogleSignIn(trusted: false);
      final failure = expectLater(
        preparation,
        throwsA(isA<FirebaseAuthException>()),
      );
      auth.persistence!.completeError(
        FirebaseAuthException(code: 'web-storage-unsupported'),
      );
      await failure;

      for (final trusted in [false, true]) {
        expect(
          () => repository.signInWithGoogle(trusted: trusted),
          throwsA(isA<FirebaseAuthException>()),
        );
      }
      expect(auth.popupProviders, isEmpty);

      auth.persistence = null;
      await repository.prepareGoogleSignIn(trusted: false);
      final login = repository.signInWithGoogle(trusted: false);
      expect(auth.popupProviders, hasLength(1));
      auth.popup.complete(_FakeCredential());
      await login;
    },
  );

  test('returns popup failures to the login page', () async {
    final auth = _FakeFirebaseAuth();
    final repository = FirebaseAuthRepository(auth: auth);
    await repository.prepareGoogleSignIn(trusted: false);
    final login = repository.signInWithGoogle(trusted: false);
    final failure = expectLater(login, throwsA(isA<FirebaseAuthException>()));
    auth.popup.completeError(FirebaseAuthException(code: 'popup-blocked'));
    await failure;
  });
}
