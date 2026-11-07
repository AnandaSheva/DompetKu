import 'dart:math';

import 'package:drift/drift.dart';

/// Numeric IDs keep existing forms/backups compatible, without sharing an
/// auto-increment counter between devices. Values fit JavaScript's safe range.
int newCloudId() {
  final random = Random.secure();
  return 1 + random.nextInt(1 << 26) * (1 << 26) + random.nextInt(1 << 26);
}

Map<String, dynamic> companionToCloud(
  Insertable<dynamic> value, {
  Map<String, dynamic> defaults = const {},
  int? id,
}) {
  final result = <String, dynamic>{...defaults};
  for (final entry in value.toColumns(false).entries) {
    final expression = entry.value;
    if (expression is! Variable) {
      throw ArgumentError('Ekspresi database tidak didukung di cloud.');
    }
    final key = entry.key.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match[1]!.toUpperCase(),
    );
    final raw = expression.value;
    result[key] = raw is DateTime ? raw.millisecondsSinceEpoch : raw;
  }
  if (id != null) result['id'] = id;
  return result;
}
