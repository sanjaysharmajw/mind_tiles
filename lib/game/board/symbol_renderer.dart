import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'game_symbol.dart';

/// One drawable piece of a symbol, defined in a 1×1 unit box.
class _Part {
  const _Part(this.path, {this.stroke = false, this.strokeWidth = 0.1});
  final Path path;
  final bool stroke;
  final double strokeWidth;
}

/// Draws every [GameSymbol] with vector paths so symbols look identical on
/// all platforms (no fonts or emoji involved).
///
/// Paths are built once per symbol in unit space and cached; drawing only
/// applies a translate/scale, which keeps the per-frame cost tiny.
class SymbolRenderer {
  SymbolRenderer._();

  static final Map<GameSymbol, List<_Part>> _cache = {};
  static final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  /// Paints [symbol] filling [rect] (a square works best) in [color].
  /// [weight] scales stroke widths (e.g. 1.25 for high-contrast theme).
  static void paint(
    Canvas canvas,
    GameSymbol symbol,
    Rect rect,
    Color color, {
    double weight = 1.0,
  }) {
    final parts = _cache.putIfAbsent(symbol, () => _build(symbol));
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width, rect.height);
    for (final part in parts) {
      if (part.stroke) {
        _stroke
          ..color = color
          ..strokeWidth = part.strokeWidth * weight;
        canvas.drawPath(part.path, _stroke);
      } else {
        _fill.color = color;
        canvas.drawPath(part.path, _fill);
      }
    }
    canvas.restore();
  }

  /// Number of drawable parts for [symbol] (used by tests to ensure every
  /// symbol actually renders something).
  static int partCount(GameSymbol symbol) =>
      _cache.putIfAbsent(symbol, () => _build(symbol)).length;

  static const double _sw = 0.09; // standard outline width

  static List<_Part> _build(GameSymbol s) {
    switch (s) {
      case GameSymbol.star:
        return [_Part(_star(5, 0.46, 0.19))];
      case GameSymbol.starOutline:
        return [_Part(_star(5, 0.42, 0.18), stroke: true, strokeWidth: _sw)];
      case GameSymbol.circleOutline:
        return [
          _Part(_circle(0.5, 0.5, 0.33), stroke: true, strokeWidth: 0.11),
        ];
      case GameSymbol.circleFilled:
        return [_Part(_circle(0.5, 0.5, 0.37))];
      case GameSymbol.heart:
        return [_Part(_heart())];
      case GameSymbol.heartOutline:
        return [_Part(_scaled(_heart(), 0.86), stroke: true, strokeWidth: _sw)];
      case GameSymbol.hexagon:
        return [_Part(_polygon(6, 0.42, math.pi / 6))];
      case GameSymbol.hexagonOutline:
        return [
          _Part(_polygon(6, 0.38, math.pi / 6), stroke: true, strokeWidth: _sw),
        ];
      case GameSymbol.cross:
        return [
          _Part(
            _line(0.22, 0.22, 0.78, 0.78)
              ..addPath(_line(0.78, 0.22, 0.22, 0.78), Offset.zero),
            stroke: true,
            strokeWidth: 0.15,
          ),
        ];
      case GameSymbol.plus:
        return [
          _Part(
            _line(0.5, 0.16, 0.5, 0.84)
              ..addPath(_line(0.16, 0.5, 0.84, 0.5), Offset.zero),
            stroke: true,
            strokeWidth: 0.16,
          ),
        ];
      case GameSymbol.diceOne:
        return [
          _Part(_pips(const [(0.5, 0.5)], 0.12)),
        ];
      case GameSymbol.diceTwo:
        return [
          _Part(_pips(const [(0.27, 0.27), (0.73, 0.73)])),
        ];
      case GameSymbol.diceThree:
        return [
          _Part(_pips(const [(0.25, 0.25), (0.5, 0.5), (0.75, 0.75)])),
        ];
      case GameSymbol.diceFour:
        return [
          _Part(
            _pips(const [
              (0.27, 0.27),
              (0.73, 0.27),
              (0.27, 0.73),
              (0.73, 0.73),
            ]),
          ),
        ];
      case GameSymbol.diceFive:
        return [
          _Part(
            _pips(const [
              (0.25, 0.25),
              (0.75, 0.25),
              (0.5, 0.5),
              (0.25, 0.75),
              (0.75, 0.75),
            ]),
          ),
        ];
      case GameSymbol.diceSix:
        return [
          _Part(
            _pips(const [
              (0.28, 0.2),
              (0.72, 0.2),
              (0.28, 0.5),
              (0.72, 0.5),
              (0.28, 0.8),
              (0.72, 0.8), //
            ], 0.085),
          ),
        ];
      case GameSymbol.triangle:
        return [_Part(_polygon(3, 0.46, -math.pi / 2, cy: 0.58))];
      case GameSymbol.triangleOutline:
        return [
          _Part(
            _polygon(3, 0.4, -math.pi / 2, cy: 0.57),
            stroke: true,
            strokeWidth: _sw,
          ),
        ];
      case GameSymbol.square:
        return [_Part(_roundRect(0.17, 0.17, 0.83, 0.83, 0.07))];
      case GameSymbol.squareOutline:
        return [
          _Part(
            _roundRect(0.2, 0.2, 0.8, 0.8, 0.05),
            stroke: true,
            strokeWidth: _sw,
          ),
        ];
      case GameSymbol.diamond:
        return [
          _Part(
            _poly(const [(0.5, 0.07), (0.84, 0.5), (0.5, 0.93), (0.16, 0.5)]),
          ),
        ];
      case GameSymbol.diamondOutline:
        return [
          _Part(
            _poly(const [(0.5, 0.12), (0.8, 0.5), (0.5, 0.88), (0.2, 0.5)]),
            stroke: true,
            strokeWidth: _sw,
          ),
        ];
      case GameSymbol.crescent:
        return [
          _Part(
            Path.combine(
              PathOperation.difference,
              _circle(0.47, 0.5, 0.38),
              _circle(0.64, 0.4, 0.31),
            ),
          ),
        ];
      case GameSymbol.lightning:
        return [
          _Part(
            _poly(const [
              (0.6, 0.05), (0.2, 0.55), (0.46, 0.55), (0.36, 0.95), //
              (0.8, 0.4), (0.54, 0.4), (0.68, 0.05),
            ]),
          ),
        ];
      case GameSymbol.club:
        final p = _circle(0.5, 0.3, 0.17)
          ..addPath(_circle(0.29, 0.55, 0.17), Offset.zero)
          ..addPath(_circle(0.71, 0.55, 0.17), Offset.zero)
          ..addPath(
            _poly(const [(0.5, 0.42), (0.62, 0.9), (0.38, 0.9)]),
            Offset.zero,
          );
        return [_Part(p)];
      case GameSymbol.spade:
        final flipped = _heart().transform(_matrix(1, -1, 0, 1));
        final body = _scaled(flipped, 0.82, cy: 0.42);
        body.addPath(
          _poly(const [(0.5, 0.52), (0.63, 0.92), (0.37, 0.92)]),
          Offset.zero,
        );
        return [_Part(body)];
      case GameSymbol.drop:
        final p = Path()
          ..moveTo(0.5, 0.06)
          ..cubicTo(0.56, 0.24, 0.8, 0.42, 0.8, 0.62)
          ..arcToPoint(
            const Offset(0.2, 0.62),
            radius: const Radius.circular(0.3),
          )
          ..cubicTo(0.2, 0.42, 0.44, 0.24, 0.5, 0.06)
          ..close();
        return [_Part(p)];
      case GameSymbol.sun:
        final rays = Path();
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          rays.addPath(
            _line(
              0.5 + math.cos(a) * 0.31,
              0.5 + math.sin(a) * 0.31,
              0.5 + math.cos(a) * 0.44,
              0.5 + math.sin(a) * 0.44,
            ),
            Offset.zero,
          );
        }
        return [
          _Part(_circle(0.5, 0.5, 0.2)),
          _Part(rays, stroke: true, strokeWidth: 0.08),
        ];
      case GameSymbol.target:
        return [
          _Part(_circle(0.5, 0.5, 0.34), stroke: true, strokeWidth: _sw),
          _Part(_circle(0.5, 0.5, 0.11)),
        ];
      case GameSymbol.flower:
        final petals = _circle(0.5, 0.29, 0.18)
          ..addPath(_circle(0.71, 0.5, 0.18), Offset.zero)
          ..addPath(_circle(0.5, 0.71, 0.18), Offset.zero)
          ..addPath(_circle(0.29, 0.5, 0.18), Offset.zero)
          ..addPath(_circle(0.5, 0.5, 0.2), Offset.zero);
        return [
          _Part(
            Path.combine(
              PathOperation.difference,
              petals,
              _circle(0.5, 0.5, 0.08),
            ),
          ),
        ];
      case GameSymbol.arrow:
        return [
          _Part(
            _poly(const [
              (0.5, 0.07), (0.87, 0.47), (0.64, 0.47), (0.64, 0.92), //
              (0.36, 0.92), (0.36, 0.47), (0.13, 0.47),
            ]),
          ),
        ];
      case GameSymbol.hourglass:
        return [
          _Part(
            _poly(const [(0.2, 0.1), (0.8, 0.1), (0.5, 0.5)])..addPath(
              _poly(const [(0.5, 0.5), (0.8, 0.9), (0.2, 0.9)]),
              Offset.zero,
            ),
          ),
        ];
      case GameSymbol.checkmark:
        final p = Path()
          ..moveTo(0.18, 0.52)
          ..lineTo(0.41, 0.75)
          ..lineTo(0.83, 0.27);
        return [_Part(p, stroke: true, strokeWidth: 0.15)];
      case GameSymbol.hexagram:
        return [
          _Part(
            _polygon(3, 0.44, -math.pi / 2)
              ..addPath(_polygon(3, 0.44, math.pi / 2), Offset.zero),
          ),
        ];
      case GameSymbol.pentagon:
        return [_Part(_polygon(5, 0.44, -math.pi / 2, cy: 0.53))];
      case GameSymbol.octagonOutline:
        return [
          _Part(_polygon(8, 0.38, math.pi / 8), stroke: true, strokeWidth: _sw),
        ];
      case GameSymbol.semicircle:
        final p = Path()
          ..moveTo(0.1, 0.66)
          ..arcToPoint(
            const Offset(0.9, 0.66),
            radius: const Radius.circular(0.4),
          )
          ..close();
        return [_Part(p)];
      case GameSymbol.stripes:
        return [
          _Part(
            _roundRect(0.14, 0.18, 0.86, 0.32, 0.07)
              ..addPath(_roundRect(0.14, 0.43, 0.86, 0.57, 0.07), Offset.zero)
              ..addPath(_roundRect(0.14, 0.68, 0.86, 0.82, 0.07), Offset.zero),
          ),
        ];
      case GameSymbol.crossInCircle:
        return [
          _Part(_circle(0.5, 0.5, 0.36), stroke: true, strokeWidth: _sw),
          _Part(
            _line(0.5, 0.3, 0.5, 0.7)
              ..addPath(_line(0.3, 0.5, 0.7, 0.5), Offset.zero),
            stroke: true,
            strokeWidth: 0.1,
          ),
        ];
      case GameSymbol.concentricSquares:
        return [
          _Part(
            _roundRect(0.16, 0.16, 0.84, 0.84, 0.04),
            stroke: true,
            strokeWidth: 0.08,
          ),
          _Part(_roundRect(0.36, 0.36, 0.64, 0.64, 0.03)),
        ];
    }
  }

  // ---- geometry helpers (unit space) ----

  static Path _circle(double cx, double cy, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

  static Path _pips(List<(double, double)> centers, [double r = 0.095]) {
    final p = Path();
    for (final c in centers) {
      p.addOval(Rect.fromCircle(center: Offset(c.$1, c.$2), radius: r));
    }
    return p;
  }

  static Path _line(double x1, double y1, double x2, double y2) => Path()
    ..moveTo(x1, y1)
    ..lineTo(x2, y2);

  static Path _poly(List<(double, double)> pts) {
    final p = Path()..moveTo(pts.first.$1, pts.first.$2);
    for (final pt in pts.skip(1)) {
      p.lineTo(pt.$1, pt.$2);
    }
    return p..close();
  }

  static Path _polygon(
    int sides,
    double r,
    double rotation, {
    double cx = 0.5,
    double cy = 0.5,
  }) {
    final pts = <(double, double)>[];
    for (var i = 0; i < sides; i++) {
      final a = rotation + i * 2 * math.pi / sides;
      pts.add((cx + math.cos(a) * r, cy + math.sin(a) * r));
    }
    return _poly(pts);
  }

  static Path _star(int points, double outer, double inner) {
    final pts = <(double, double)>[];
    const cx = 0.5, cy = 0.53;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / points;
      pts.add((cx + math.cos(a) * r, cy + math.sin(a) * r));
    }
    return _poly(pts);
  }

  static Path _roundRect(
    double l,
    double t,
    double r,
    double b,
    double radius,
  ) => Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

  static Path _heart() => Path()
    ..moveTo(0.5, 0.86)
    ..cubicTo(0.5, 0.86, 0.07, 0.6, 0.07, 0.35)
    ..cubicTo(0.07, 0.2, 0.18, 0.12, 0.3, 0.12)
    ..cubicTo(0.4, 0.12, 0.47, 0.18, 0.5, 0.27)
    ..cubicTo(0.53, 0.18, 0.6, 0.12, 0.7, 0.12)
    ..cubicTo(0.82, 0.12, 0.93, 0.2, 0.93, 0.35)
    ..cubicTo(0.93, 0.6, 0.5, 0.86, 0.5, 0.86)
    ..close();

  /// Scales [p] about (0.5, [cy]).
  static Path _scaled(Path p, double factor, {double cy = 0.5}) {
    final m = Float64List.fromList([
      factor, 0, 0, 0, //
      0, factor, 0, 0,
      0, 0, 1, 0,
      0.5 * (1 - factor), cy - 0.5 * factor, 0, 1,
    ]);
    return p.transform(m);
  }

  /// Column-major 4×4 matrix: scale (sx, sy) then translate (tx, ty).
  static Float64List _matrix(double sx, double sy, double tx, double ty) =>
      Float64List.fromList([
        sx, 0, 0, 0, //
        0, sy, 0, 0,
        0, 0, 1, 0,
        tx, ty, 0, 1,
      ]);
}
