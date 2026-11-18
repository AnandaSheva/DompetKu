import 'package:flutter/foundation.dart';

import 'auth_repository.dart';
import 'browser_session.dart';
import '../store/cloud_finance_store.dart';
import '../notifications/native_bill_notifications.dart';

Future<void> endWebSession(
  AuthRepository auth,
  CloudFinanceStore? store, {
  bool discardPending = false,
}) async {
  // Refuse to discard writes that have not reached the server.
  if (!discardPending) await store?.waitForSync();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await cancelNativeBillReminders();
  }
  await store?.close();
  if (store != null) {
    await store.firestore.terminate();
    try {
      await store.firestore.clearPersistence();
    } catch (_) {
      if (!kIsWeb) rethrow;
      setSessionNotice(
        'Sesi sudah keluar. Cache browser belum dapat dibersihkan. '
        'Tutup tab DompetKu lain dan hapus data situs jika memakai perangkat bersama.',
      );
    }
    savePendingWrites(store.uid, null);
    await flushSessionStorage();
  }
  try {
    await auth.signOut();
    rememberDevice(false);
    warnBeforeLeaving(false);
  } finally {
    // A terminated Firestore instance must be recreated on a fresh page.
    reloadBrowser();
  }
}
