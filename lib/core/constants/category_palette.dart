abstract final class CategoryPalette {
  static const royal = 0xFF1D4ED8;
  static const ocean = 0xFF0369A1;
  static const blue = 0xFF2563EB;
  static const navy = 0xFF1E40AF;
  static const sky = 0xFF0E7490;
  static const slate = 0xFF475569;

  static const values = [royal, ocean, blue, navy, sky, slate];

  // Resolve earlier/imported colors for display without rewriting stored data.
  static int resolve(int value) {
    if (values.contains(value)) return value;
    return switch (value) {
      0xFFDC2626 => values[0],
      0xFFF97316 => values[1],
      0xFF0F766E => values[2],
      0xFF16A34A => values[4],
      0xFF6B7280 => values[5],
      _ => values[(value & 0xFFFFFF) % values.length],
    };
  }
}
