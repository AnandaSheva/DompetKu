import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

SharedPreferences? _preferences;
final _values = <String, String>{};
final _dirty = <String, String?>{};
Future<void> _writing = Future.value();
const _prefix = 'dompetku.session.';

Future<void> initializeSessionStorage() async {
  _preferences = await SharedPreferences.getInstance();
  _values.clear();
  for (final key in _preferences!.getKeys().where(
    (key) => key.startsWith(_prefix),
  )) {
    final value = _preferences!.getString(key);
    if (value != null) _values[key] = value;
  }
}

String? _read(String key) => _values['$_prefix$key'];
void _save(String key, String? value) {
  final storageKey = '$_prefix$key';
  if (value == null) {
    _values.remove(storageKey);
  } else {
    _values[storageKey] = value;
  }
  _dirty[storageKey] = value;
  // Serialize storage writes; failed values remain dirty until a successful retry.
  _writing = _writing
      .then((_) => _persist(storageKey, value))
      .catchError((Object _) {});
}

Future<void> _persist(String key, String? value) async {
  final preferences = _preferences;
  if (preferences == null) {
    throw StateError('Penyimpanan perangkat belum siap.');
  }
  final saved = value == null
      ? await preferences.remove(key)
      : await preferences.setString(key, value);
  if (!saved) throw StateError('Perubahan perangkat belum tersimpan.');
  if (_dirty.containsKey(key) && _dirty[key] == value) _dirty.remove(key);
}

Future<void> flushSessionStorage() async {
  await _writing;
  for (final entry in Map.of(_dirty).entries) {
    await _persist(entry.key, entry.value);
  }
}

String _accountKey(String uid) => sha256.convert(utf8.encode(uid)).toString();
bool get trustedDevice => _preferences != null;
void rememberDevice(bool value) {}
void reloadBrowser() {}
void warnBeforeLeaving(bool value) {}
void setSessionNotice(String value) => _save('notice', value);
String? takeSessionNotice() {
  final notice = _read('notice');
  if (notice != null) _save('notice', null);
  return notice;
}

String? readPendingWrites(String uid) => _read('pending.${_accountKey(uid)}');
void savePendingWrites(String uid, String? value) =>
    _save('pending.${_accountKey(uid)}', value);
bool get isLoginRoute => true;
void openLoginRoute() {}
void openAccountRoute() {}
String? get legacyOwner => _read('legacy-owner');
void rememberLegacyOwner(String uid) => _save('legacy-owner', uid);
bool legacyDeviceMigrationComplete(String uid) =>
    _read('legacy-complete.${_accountKey(uid)}') == 'true';
void rememberLegacyDeviceMigration(String uid) =>
    _save('legacy-complete.${_accountKey(uid)}', 'true');
