import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dompet_sheva/data/auth/browser_session_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'pending writes survive restart, remain isolated by account, and clear in order',
    () async {
      SharedPreferences.setMockInitialValues({});
      await initializeSessionStorage();
      savePendingWrites('alice', '{"pending":"alice"}');
      savePendingWrites('bob', '{"pending":"bob"}');
      rememberLegacyOwner('alice');
      rememberLegacyDeviceMigration('alice');
      await flushSessionStorage();
      await initializeSessionStorage();
      expect(readPendingWrites('alice'), contains('alice'));
      expect(readPendingWrites('bob'), contains('bob'));
      expect(readPendingWrites('charlie'), isNull);
      expect(legacyOwner, 'alice');
      expect(legacyDeviceMigrationComplete('alice'), isTrue);
      expect(legacyDeviceMigrationComplete('bob'), isFalse);
      savePendingWrites('alice', 'older-retry');
      savePendingWrites('alice', null);
      await flushSessionStorage();
      await initializeSessionStorage();
      expect(readPendingWrites('alice'), isNull);
      expect(readPendingWrites('bob'), contains('bob'));
      expect(
        (await SharedPreferences.getInstance()).getKeys().any(
          (key) => key.contains('alice'),
        ),
        isFalse,
      );
    },
  );
}
