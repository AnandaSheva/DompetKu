import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'features/auth/firebase_startup_error.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    const useEmulators =
        kDebugMode && bool.fromEnvironment('FIREBASE_EMULATORS');
    try {
      await Firebase.initializeApp(
        options: useEmulators
            ? const FirebaseOptions(
                apiKey: 'demo-api-key',
                appId: '1:123456789:web:dompetku',
                messagingSenderId: '123456789',
                projectId: 'demo-dompetku',
              )
            : DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      runApp(const FirebaseStartupError());
      return;
    }
    if (useEmulators) {
      await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    }
  }
  await initializeDateFormatting('id_ID');
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ProviderScope(child: DompetShevaApp()));
}
