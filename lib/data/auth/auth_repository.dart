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
  Future<void> prepareGoogleSignIn({required bool trusted});
  Future<void> signInWithGoogle({required bool trusted});
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth}) : _providedAuth = auth;

  final FirebaseAuth? _providedAuth;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;
  bool? _preparedTrusted;

  @override
  Stream<AppAccount?> authStateChanges() => _auth.authStateChanges().map(
    (user) => user == null
        ? null
        : AppAccount(uid: user.uid, name: user.displayName, email: user.email),
  );

  @override
  Future<void> prepareGoogleSignIn({required bool trusted}) async {
    _preparedTrusted = null;
    await _auth.setPersistence(
      trusted ? Persistence.LOCAL : Persistence.SESSION,
    );
    _preparedTrusted = trusted;
  }

  @override
  Future<void> signInWithGoogle({required bool trusted}) {
    if (_preparedTrusted != trusted) {
      throw FirebaseAuthException(code: 'session-not-ready');
    }
    rememberDevice(trusted);
    // Open directly from the tap. Awaiting storage here can lose the user
    // activation required for popups by Safari and installed mobile PWAs.
    return _auth
        .signInWithPopup(
          GoogleAuthProvider()
            ..setCustomParameters({'prompt': 'select_account'}),
        )
        .then((_) {});
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
        'Popup Google diblokir. Izinkan popup di Safari atau Chrome, lalu coba lagi.',
      'web-storage-unsupported' || 'session-not-ready' =>
        'Sesi login belum siap. Izinkan penyimpanan situs di browser, lalu coba lagi.',
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
