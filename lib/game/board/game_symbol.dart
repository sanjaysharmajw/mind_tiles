/// Every symbol that can appear on a tile.
///
/// Symbols are grouped in [tier]s by how easy they are to tell apart:
/// * tier 1 – bold, clearly distinct silhouettes (the reference board set).
/// * tier 2 – outline/filled variants of tier-1 shapes and new silhouettes.
/// * tier 3 – visually close shapes (dice faces, polygons) for expert play.
///
/// The enum order is part of the save format (snapshots store [name]), so new
/// symbols must be appended rather than inserted.
enum GameSymbol {
  // Tier 1 — distinct silhouettes inspired by the yellow reference board.
  star(1, 'five-point star'),
  circleOutline(1, 'outlined circle'),
  heart(1, 'heart'),
  hexagon(1, 'hexagon'),
  cross(1, 'X cross'),
  diceFive(1, 'dice five'),
  triangle(1, 'triangle'),
  square(1, 'square'),
  diamond(1, 'diamond'),
  crescent(1, 'crescent moon'),
  plus(1, 'plus sign'),
  lightning(1, 'lightning bolt'),
  club(1, 'club'),
  spade(1, 'spade'),
  drop(1, 'water drop'),
  sun(1, 'sun'),

  // Tier 2 — variants and new shapes.
  circleFilled(2, 'filled circle'),
  starOutline(2, 'outlined star'),
  heartOutline(2, 'outlined heart'),
  hexagonOutline(2, 'outlined hexagon'),
  triangleOutline(2, 'outlined triangle'),
  squareOutline(2, 'outlined square'),
  diamondOutline(2, 'outlined diamond'),
  target(2, 'target ring'),
  flower(2, 'flower'),
  arrow(2, 'up arrow'),
  hourglass(2, 'hourglass'),
  checkmark(2, 'check mark'),

  // Tier 3 — easily confused shapes.
  diceOne(3, 'dice one'),
  diceTwo(3, 'dice two'),
  diceThree(3, 'dice three'),
  diceFour(3, 'dice four'),
  diceSix(3, 'dice six'),
  hexagram(3, 'six-point star'),
  pentagon(3, 'pentagon'),
  octagonOutline(3, 'outlined octagon'),
  semicircle(3, 'half circle'),
  stripes(3, 'three stripes'),
  crossInCircle(3, 'plus in a circle'),
  concentricSquares(3, 'square in a square');

  const GameSymbol(this.tier, this.label);

  /// Difficulty tier (1–3).
  final int tier;

  /// Human readable name used for accessibility labels.
  final String label;

  static const int maxTier = 3;

  /// All symbols whose tier is <= [tier], in declaration order.
  static List<GameSymbol> upToTier(int tier) =>
      values.where((s) => s.tier <= tier).toList(growable: false);

  static GameSymbol? tryParse(String name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}
