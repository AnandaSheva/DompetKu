import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

abstract interface class NativeGoogleLogin {
  Future<void> prepare();
  Future<String> idToken();
  Future<void> signOut();
}

class AndroidGoogleLogin implements NativeGoogleLogin {
  static Future<void>? _initialization;

  @override
  Future<void> prepare() {
    const clientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    if (clientId.isEmpty) {
      throw FirebaseAuthException(code: 'android-config-missing');
    }
    return _initialization ??= GoogleSignIn.instance
        .initialize(serverClientId: clientId)
        .catchError((Object error) {
          _initialization = null;
          throw error;
        });
  }

  @override
  Future<String> idToken() async {
    final account = await GoogleSignIn.instance.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    return token;
  }

  @override
  Future<void> signOut() async {
    if (_initialization != null) await GoogleSignIn.instance.signOut();
  }
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    this.isWeb = kIsWeb,
    NativeGoogleLogin? nativeGoogle,
  }) : _providedAuth = auth,
       _nativeGoogle = nativeGoogle ?? AndroidGoogleLogin();

  final FirebaseAuth? _providedAuth;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;
  final bool isWeb;
  final NativeGoogleLogin _nativeGoogle;
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
    if (isWeb) {
      await _auth.setPersistence(
        trusted ? Persistence.LOCAL : Persistence.SESSION,
      );
    } else {
      await _nativeGoogle.prepare();
    }
    _preparedTrusted = trusted;
  }

  @override
  Future<void> signInWithGoogle({required bool trusted}) {
    if (_preparedTrusted != trusted) {
      throw FirebaseAuthException(code: 'session-not-ready');
    }
    if (!isWeb) return _signInNative();
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

  Future<void> _signInNative() async {
    final token = await _nativeGoogle.idToken();
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: token),
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (!isWeb) {
      try {
        await _nativeGoogle.signOut();
      } catch (_) {
        // A Google chooser cleanup failure must not restore the Firebase session.
      }
    }
  }
}

String authErrorMessage(Object error) {
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled =>
        'Login dibatalkan. Silakan coba lagi.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Login Android belum dikonfigurasi. Periksa client ID dan sertifikat aplikasi di Firebase.',
      _ => 'Belum bisa masuk dengan Google. Periksa koneksi lalu coba lagi.',
    };
  }
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
      'android-config-missing' =>
        'Konfigurasi login Android belum lengkap. Gunakan build dengan konfigurasi Firebase Android.',
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
