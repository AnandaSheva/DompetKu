import 'package:firebase_auth/firebase_auth.dart';

import 'browser_session.dart';

class AppAccount {
  const AppAccount({required this.uid, this.name, this.email});
  final String uid;
  final String? name;
  final String? email;
}

abstract interface class AuthRepository {
  Stream<AppAccount?> authStateChanges();
  Future<void> signInWithGoogle({required bool trusted});
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  Stream<AppAccount?> authStateChanges() => _auth.authStateChanges().map(
    (user) => user == null
        ? null
        : AppAccount(uid: user.uid, name: user.displayName, email: user.email),
  );

  @override
  Future<void> signInWithGoogle({required bool trusted}) async {
    await _auth.setPersistence(
      trusted ? Persistence.LOCAL : Persistence.SESSION,
    );
    rememberDevice(trusted);
    await _auth.signInWithPopup(
      GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}),
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'popup-closed-by-user' ||
      'cancelled-popup-request' => 'Login dibatalkan. Silakan coba lagi.',
      'popup-blocked' =>
        'Izinkan popup untuk masuk dengan Google, lalu coba lagi.',
      'unauthorized-domain' =>
        'Domain ini belum diizinkan di Firebase Authentication.',
      'operation-not-allowed' =>
        'Login Google belum diaktifkan untuk aplikasi ini.',
      'network-request-failed' =>
        'Tidak ada koneksi. Hubungkan internet untuk masuk.',
      'too-many-requests' =>
        'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
      _ => 'Belum bisa masuk dengan Google. Silakan coba lagi.',
    };
  }
  return 'Belum bisa masuk dengan Google. Silakan coba lagi.';
}
