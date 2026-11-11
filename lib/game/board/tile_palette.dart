import 'dart:ui';

/// Player-selectable tile themes.
enum TileThemeId {
  classic('Sunny Yellow'),
  midnight('Midnight'),
  highContrast('High Contrast');

  const TileThemeId(this.label);
  final String label;

  static TileThemeId parse(Object? v) => TileThemeId.values.firstWhere(
    (t) => t.name == v,
    orElse: () => TileThemeId.classic,
  );
}

/// Colours used to draw tiles. The classic palette recreates the yellow
/// physical board: warm yellow faces with near-black symbols.
class TilePalette {
  const TilePalette({
    required this.faceTop,
    required this.faceBottom,
    required this.faceEdge,
    required this.symbol,
    required this.backTop,
    required this.backBottom,
    required this.backEdge,
    required this.backPattern,
    this.symbolWeight = 1.0,
    this.outline,
  });

  final Color faceTop;
  final Color faceBottom;
  final Color faceEdge;
  final Color symbol;
  final Color backTop;
  final Color backBottom;
  final Color backEdge;
  final Color backPattern;
  final double symbolWeight;
  final Color? outline;

  static const Color matched = Color(0xFF16A34A);
  static const Color mismatch = Color(0xFFDC2626);
  static const Color hint = Color(0xFFFFFFFF);

  static TilePalette of(TileThemeId id) => switch (id) {
    TileThemeId.classic => classic,
    TileThemeId.midnight => midnight,
    TileThemeId.highContrast => highContrast,
  };

  static const classic = TilePalette(
    faceTop: Color(0xFFFFE270),
    faceBottom: Color(0xFFFFC928),
    faceEdge: Color(0xFFD69200),
    symbol: Color(0xFF1C1917),
    backTop: Color(0xFFFF8F5A),
    backBottom: Color(0xFFF2582A),
    backEdge: Color(0xFFB33A12),
    backPattern: Color(0x55FFFFFF),
  );

  static const midnight = TilePalette(
    faceTop: Color(0xFF3A3F63),
    faceBottom: Color(0xFF272B47),
    faceEdge: Color(0xFF14172B),
    symbol: Color(0xFFFFD43B),
    backTop: Color(0xFF6C7BF2),
    backBottom: Color(0xFF4C59D6),
    backEdge: Color(0xFF2E3794),
    backPattern: Color(0x44FFFFFF),
  );

  static const highContrast = TilePalette(
    faceTop: Color(0xFFFFFFFF),
    faceBottom: Color(0xFFF2F2F2),
    faceEdge: Color(0xFF9E9E9E),
    symbol: Color(0xFF000000),
    backTop: Color(0xFF1A1A1A),
    backBottom: Color(0xFF000000),
    backEdge: Color(0xFF000000),
    backPattern: Color(0x99FFFFFF),
    symbolWeight: 1.25,
    outline: Color(0xFFFFFFFF),
  );
}

/// Visual options the Flame game needs from the player's settings.
class GameVisuals {
  const GameVisuals({required this.palette, required this.reducedMotion});
  final TilePalette palette;
  final bool reducedMotion;
}
