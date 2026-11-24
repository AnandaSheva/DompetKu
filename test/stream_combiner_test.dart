import 'dart:async';

import 'package:dompet_sheva/core/helpers/calculation_helper.dart';
import 'package:dompet_sheva/core/helpers/stream_combiner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('combineLatest', () {
    test('waits for every source and coalesces same-turn updates', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final results = <int>[];
      final sub = combineLatest<int>(
        [a.stream, b.stream],
        (values) => (values[0] as int) + (values[1] as int),
      ).listen(results.add);

      a.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(results, isEmpty);

      b.add(10);
      a.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(results, [12]);

      b.add(20);
      await Future<void>.delayed(Duration.zero);
      expect(results, [12, 22]);

      await sub.cancel();
      expect(a.hasListener, isFalse);
      expect(b.hasListener, isFalse);
      await a.close();
      await b.close();
    });

    test('does not subscribe until the result is listened to', () async {
      final source = StreamController<int>();
      final stream = combineLatest<int>([
        source.stream,
      ], (values) => values[0] as int);
      expect(source.hasListener, isFalse);
      final sub = stream.listen((_) {});
      expect(source.hasListener, isTrue);
      await sub.cancel();
      expect(source.hasListener, isFalse);
      await source.close();
    });

    test('reports a failing combiner as a stream error', () async {
      final source = StreamController<int>();
      final errors = <Object>[];
      final sub = combineLatest<int>(
        [source.stream],
        (values) => throw StateError('boom'),
      ).listen((_) {}, onError: errors.add);
      source.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(errors.single, isA<StateError>());
      await sub.cancel();
      await source.close();
    });
  });

  test('walletBalances matches walletBalance for every wallet', () {
    const rows = [
      (walletId: 1, transferWalletId: null, type: 'income', amount: 500),
      (walletId: 1, transferWalletId: null, type: 'expense', amount: 120),
      (walletId: 1, transferWalletId: 2, type: 'transfer', amount: 200),
      (walletId: 2, transferWalletId: null, type: 'expense', amount: 30),
      // Unknown wallet ids are ignored, like a deleted wallet.
      (walletId: 9, transferWalletId: 1, type: 'transfer', amount: 70),
    ];
    const initial = {1: 1000, 2: 50};

    final batch = CalculationHelper.walletBalances(
      initialBalances: initial,
      transactions: rows,
    );

    for (final entry in initial.entries) {
      expect(
        batch[entry.key],
        CalculationHelper.walletBalance(
          walletId: entry.key,
          initialBalance: entry.value,
          transactions: rows,
        ),
      );
    }
  });
}
