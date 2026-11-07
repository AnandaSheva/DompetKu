import 'auth_repository.dart';
import 'browser_session.dart';
import '../store/cloud_finance_store.dart';

Future<void> endWebSession(
  AuthRepository auth,
  CloudFinanceStore? store, {
  bool discardPending = false,
}) async {
  // Refuse to discard writes that have not reached the server.
  if (!discardPending) await store?.waitForSync();
  await store?.close();
  if (store != null) {
    await store.firestore.terminate();
    try {
      await store.firestore.clearPersistence();
      savePendingWrites(store.uid, null);
    } catch (_) {
      setSessionNotice(
        'Sesi sudah keluar. Cache browser belum dapat dibersihkan. '
        'Tutup tab DompetKu lain dan hapus data situs jika memakai perangkat bersama.',
      );
    }
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
