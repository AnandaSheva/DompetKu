import 'dart:async';

/// Emits `combine(latestValues)` once every source has produced a value, then
/// again after any source changes.
///
/// Sources are subscribed only while the result is listened to. Changes that
/// arrive in the same event-loop turn (for example the initial snapshot of
/// several collections) are coalesced into one emission, so derived data is
/// computed once instead of once per source.
///
/// Source errors are reported to the current zone, as before. Cloud errors are
/// surfaced to the user through the account sync status instead of failing
/// every derived stream.
Stream<R> combineLatest<R>(
  List<Stream<Object?>> sources,
  R Function(List<Object?> values) combine,
) {
  final subscriptions = <StreamSubscription<Object?>>[];
  late final StreamController<R> controller;

  controller = StreamController<R>(
    onListen: () {
      final values = List<Object?>.filled(sources.length, null);
      final received = List<bool>.filled(sources.length, false);
      var receivedCount = 0;
      var scheduled = false;

      void flush() {
        scheduled = false;
        if (controller.isClosed) return;
        try {
          controller.add(combine(List<Object?>.unmodifiable(values)));
        } catch (error, stack) {
          controller.addError(error, stack);
        }
      }

      for (var index = 0; index < sources.length; index++) {
        subscriptions.add(
          sources[index].listen((value) {
            values[index] = value;
            if (!received[index]) {
              received[index] = true;
              receivedCount++;
            }
            if (receivedCount == sources.length && !scheduled) {
              scheduled = true;
              scheduleMicrotask(flush);
            }
          }, onError: Zone.current.handleUncaughtError),
        );
      }
    },
    onCancel: () async {
      await Future.wait(subscriptions.map((sub) => sub.cancel()));
      subscriptions.clear();
    },
  );

  return controller.stream;
}
