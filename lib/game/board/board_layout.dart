import 'dart:math';
import 'dart:ui';

/// Pure geometry for a board of [columns] × [rows] tiles.
///
/// Used twice: by the Flutter gameplay screen to decide how big the game
/// canvas should be (and whether it needs to scroll), and by the Flame game to
/// place tiles and convert tap positions into tile indices.
class BoardLayout {
  BoardLayout._({
    required this.columns,
    required this.rows,
    required this.tileSize,
    required this.gap,
    required this.padding,
  });

  /// Smallest comfortable tile edge in logical pixels. Boards that would need
  /// smaller tiles get this size and scroll instead.
  static const double minTileSize = 40;

  /// Largest tile edge, so tablets do not get absurdly big tiles.
  static const double maxTileSize = 120;

  /// Gap between tiles as a fraction of the tile size.
  static const double gapRatio = 0.08;

  final int columns;
  final int rows;
  final double tileSize;
  final double gap;

  /// Margin around the grid (room for shadows and particles).
  final double padding;

  double get pitch => tileSize + gap;
  double get gridWidth => columns * tileSize + (columns - 1) * gap;
  double get gridHeight => rows * tileSize + (rows - 1) * gap;
  Size get canvasSize =>
      Size(gridWidth + padding * 2, gridHeight + padding * 2);

  /// Fits the board into [available]. If even [minTileSize] tiles do not fit
  /// vertically, the board keeps [minTileSize] and [needsScroll] is true.
  factory BoardLayout.fit({
    required int columns,
    required int rows,
    required Size available,
    double padding = 6,
  }) {
    final w = max(0.0, available.width - padding * 2);
    final h = max(0.0, available.height - padding * 2);
    // tile*cols + gapRatio*tile*(cols-1) = w
    final byWidth = w / (columns + gapRatio * (columns - 1));
    final byHeight = h / (rows + gapRatio * (rows - 1));
    var tile = min(min(byWidth, byHeight), maxTileSize);
    if (tile < minTileSize) {
      // Grow tiles up to the minimum, but never wider than the available
      // width (no horizontal scrolling); extra rows scroll vertically.
      tile = max(tile, min(minTileSize, byWidth));
    }
    tile = max(tile, 1);
    return BoardLayout._(
      columns: columns,
      rows: rows,
      tileSize: tile,
      gap: tile * gapRatio,
      padding: padding,
    );
  }

  /// Layout derived from an already-sized canvas (inside the Flame game).
  factory BoardLayout.forCanvas({
    required int columns,
    required int rows,
    required Size canvas,
    double padding = 6,
  }) {
    final w = max(0.0, canvas.width - padding * 2);
    final h = max(0.0, canvas.height - padding * 2);
    final byWidth = w / (columns + gapRatio * (columns - 1));
    final byHeight = h / (rows + gapRatio * (rows - 1));
    final tile = max(1.0, min(byWidth, byHeight));
    return BoardLayout._(
      columns: columns,
      rows: rows,
      tileSize: tile,
      gap: tile * gapRatio,
      padding: padding,
    );
  }

  /// Whether the board is taller than [viewportHeight] and must scroll.
  bool needsScroll(double viewportHeight) =>
      canvasSize.height > viewportHeight + 0.5;

  /// Offset that centres the grid within a canvas of [canvas] size.
  Offset originIn(Size canvas) =>
      Offset((canvas.width - gridWidth) / 2, (canvas.height - gridHeight) / 2);

  Rect tileRect(int index, Offset origin) {
    final col = index % columns;
    final row = index ~/ columns;
    return Rect.fromLTWH(
      origin.dx + col * pitch,
      origin.dy + row * pitch,
      tileSize,
      tileSize,
    );
  }

  /// Converts a point (in canvas coordinates) to a tile index, or null when
  /// the point is outside the grid or falls in the gap between tiles.
  int? indexAt(Offset point, Offset origin) {
    final x = point.dx - origin.dx;
    final y = point.dy - origin.dy;
    if (x < 0 || y < 0 || x > gridWidth || y > gridHeight) return null;
    final col = (x / pitch).floor();
    final row = (y / pitch).floor();
    if (col < 0 || col >= columns || row < 0 || row >= rows) return null;
    if (x - col * pitch > tileSize || y - row * pitch > tileSize) return null;
    return row * columns + col;
  }
}
