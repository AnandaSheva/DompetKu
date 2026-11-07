import 'dart:js_interop';

@JS('window')
external _Window get _window;

extension type _Window(JSObject _) implements JSObject {
  external _Storage get localStorage;
  external _Storage get sessionStorage;
  external _Location get location;
  external void addEventListener(String event, JSFunction callback);
}
extension type _Storage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}
extension type _Location(JSObject _) implements JSObject {
  external void reload();
  external String get pathname;
  external void replace(String path);
}
extension type _BeforeUnloadEvent(JSObject _) implements JSObject {
  external void preventDefault();
  external set returnValue(String value);
}

bool get trustedDevice {
  try {
    return _window.localStorage.getItem('dompetku.trusted-device') == 'true';
  } catch (_) {
    return false;
  }
}

void rememberDevice(bool value) {
  try {
    _window.localStorage.setItem('dompetku.trusted-device', '$value');
  } catch (_) {
    /* Storage can be unavailable in private browsing. */
  }
}

void reloadBrowser() => _window.location.reload();
bool get isLoginRoute => _window.location.pathname == '/login';
void openLoginRoute() => _window.location.replace('/login');
void openAccountRoute() => _window.location.replace('/');
String? get legacyOwner {
  try {
    return _window.localStorage.getItem('dompetku.legacy-owner');
  } catch (_) {
    return null;
  }
}

void rememberLegacyOwner(String uid) {
  _window.localStorage.setItem('dompetku.legacy-owner', uid);
}

bool _pending = false;
bool _registered = false;
void warnBeforeLeaving(bool value) {
  _pending = value;
  if (_registered) return;
  _registered = true;
  _window.addEventListener(
    'beforeunload',
    ((_BeforeUnloadEvent event) {
      if (_pending) {
        event.preventDefault();
        event.returnValue = '';
      }
    }).toJS,
  );
}

void setSessionNotice(String value) {
  try {
    _window.sessionStorage.setItem('dompetku.session-notice', value);
  } catch (_) {}
}

String? takeSessionNotice() {
  try {
    final notice = _window.sessionStorage.getItem('dompetku.session-notice');
    _window.sessionStorage.removeItem('dompetku.session-notice');
    return notice;
  } catch (_) {
    return null;
  }
}

String? readPendingWrites(String uid) {
  if (!trustedDevice) return null;
  try {
    return _window.localStorage.getItem('dompetku.pending.$uid');
  } catch (_) {
    return null;
  }
}

void savePendingWrites(String uid, String? value) {
  if (!trustedDevice) return;
  // A failed write must remain recoverable even when the SDK rejects it.
  // Store it only after explicit consent to persistent storage on this device.
  if (value == null) {
    _window.localStorage.removeItem('dompetku.pending.$uid');
  } else {
    _window.localStorage.setItem('dompetku.pending.$uid', value);
  }
}
