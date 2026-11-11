import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_state.dart';
import 'game_symbol.dart';
import 'symbol_renderer.dart';
import 'tile_palette.dart';

/// Renders a single tile. All gameplay state is read from the [GameSession]
/// each frame; this component only owns animation state (flip progress,
/// press, pulse, shake), so there is a single source of truth.
class TileComponent extends PositionComponent {
  TileComponent({
    required this.index,
    required this.symbol,
    required this.sessionGetter,
    required this.visualsGetter,
  });

  final int index;
  final GameSymbol symbol;
  final GameSession Function() sessionGetter;
  final GameVisuals Function() visualsGetter;

  static const double flipDuration = 0.24;
  static const double pulseDuration = 0.4;
  static const double shakeDuration = 0.4;

  /// 0 = back showing, 1 = face showing.
  double _flip = 0;
  bool _initialised = false;
  double _press = 0; // 0..1
  bool _pressed = false;
  double _pulse = 0; // remaining pulse time
  double _shake = 0; // remaining shake time
  double _celebrateDelay = -1;
  double _time = 0;

  // Reused paints/objects to avoid allocations in render().
  final Paint _paint = Paint()..isAntiAlias = true;
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final Paint _shadowPaint = Paint()..color = const Color(0x40000000);
  final Paint _highlightPaint = Paint()..color = const Color(0x33FFFFFF);
  Shader? _faceShader;
  Shader? _backShader;
  TilePalette? _shaderPalette;
  double _shaderSize = -1;

  void pressDown() => _pressed = true;
  void pressUp() => _pressed = false;
  void pulse() => _pulse = pulseDuration;
  void shake() => _shake = shakeDuration;
  void celebrate(double delay) => _celebrateDelay = delay;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final session = sessionGetter();
    final reduced = visualsGetter().reducedMotion;
    final target = session.isFaceUp(index) ? 1.0 : 0.0;
    if (!_initialised || reduced) {
      _flip = target;
      _initialised = true;
    } else if (_flip != target) {
      final step = dt / flipDuration;
      _flip = target > _flip
          ? math.min(target, _flip + step)
          : math.max(target, _flip - step);
    }
    final pressTarget = _pressed ? 1.0 : 0.0;
    _press += (pressTarget - _press) * math.min(1, dt * 25);
    if (_pulse > 0) _pulse = math.max(0, _pulse - dt);
    if (_shake > 0) _shake = math.max(0, _shake - dt);
    if (_celebrateDelay >= 0) {
      _celebrateDelay -= dt;
      if (_celebrateDelay < 0) {
        _celebrateDelay = -1;
        _pulse = pulseDuration;
      }
    }
  }

  void _ensureShaders(TilePalette p, double s) {
    if (_shaderPalette == p && _shaderSize == s) return;
    _shaderPalette = p;
    _shaderSize = s;
    _faceShader = Gradient.linear(Offset.zero, Offset(0, s), [
      p.faceTop,
      p.faceBottom,
    ]);
    _backShader = Gradient.linear(Offset.zero, Offset(0, s), [
      p.backTop,
      p.backBottom,
    ]);
  }

  @override
  void render(Canvas canvas) {
    final s = size.x;
    if (s <= 0) return;
    final visuals = visualsGetter();
    final p = visuals.palette;
    final session = sessionGetter();
    _ensureShaders(p, s);

    final reduced = visuals.reducedMotion;
    final flipScale = math.cos(math.pi * _flip).abs().clamp(0.02, 1.0);
    final showFace = _flip >= 0.5;
    final pressScale = 1 - 0.07 * _press;
    final pulseT = _pulse > 0 && !reduced
        ? math.sin(math.pi * (1 - _pulse / pulseDuration))
        : 0.0;
    final scale = pressScale * (1 + 0.1 * pulseT);
    final shakeT = _shake > 0 && !reduced ? _shake / shakeDuration : 0.0;
    final shakeX = math.sin(_time * 55) * s * 0.06 * shakeT;

    final radius = Radius.circular(s * 0.18);
    final edge = s * 0.06;

    canvas.save();
    canvas.translate(s / 2 + shakeX, s / 2);
    canvas.scale(flipScale * scale, scale);
    canvas.translate(-s / 2, -s / 2);

    // Drop shadow.
    canvas.drawRRect(
      RRect.fromLTRBR(s * 0.02, edge * 1.6, s * 0.98, s + edge * 0.6, radius),
      _shadowPaint,
    );

    // 3D edge (bottom bevel) then the top surface.
    _paint
      ..shader = null
      ..color = showFace ? p.faceEdge : p.backEdge;
    canvas.drawRRect(RRect.fromLTRBR(0, edge, s, s, radius), _paint);
    _paint.shader = showFace ? _faceShader : _backShader;
    canvas.drawRRect(RRect.fromLTRBR(0, 0, s, s - edge, radius), _paint);
    _paint.shader = null;

    // Glossy highlight.
    canvas.drawRRect(
      RRect.fromLTRBR(
        s * 0.1,
        s * 0.05,
        s * 0.9,
        s * 0.3,
        Radius.circular(s * 0.12),
      ),
      _highlightPaint,
    );

    final face = Rect.fromLTWH(0, 0, s, s - edge);
    if (showFace) {
      final inset = s * 0.2;
      SymbolRenderer.paint(
        canvas,
        symbol,
        Rect.fromLTWH(inset, inset - edge / 2, s - inset * 2, s - inset * 2),
        p.symbol,
        weight: p.symbolWeight,
      );
    } else {
      _drawBackPattern(canvas, face, p);
    }

    final outline = p.outline;
    if (outline != null) {
      _strokePaint
        ..color = outline
        ..strokeWidth = math.max(1.5, s * 0.03);
      canvas.drawRRect(RRect.fromRectAndRadius(face, radius), _strokePaint);
    }

    final matched = session.board.tiles[index].isMatched;
    if (matched && showFace) {
      _strokePaint
        ..color = TilePalette.matched
        ..strokeWidth = math.max(2.5, s * 0.06);
      canvas.drawRRect(
        RRect.fromRectAndRadius(face.deflate(s * 0.03), radius),
        _strokePaint,
      );
      _drawBadge(canvas, s, TilePalette.matched, check: true);
    } else if (session.isMismatched(index) && showFace) {
      _strokePaint
        ..color = TilePalette.mismatch
        ..strokeWidth = math.max(2.5, s * 0.06);
      canvas.drawRRect(
        RRect.fromRectAndRadius(face.deflate(s * 0.03), radius),
        _strokePaint,
      );
      _drawBadge(canvas, s, TilePalette.mismatch, check: false);
    }

    if (session.isHinted(index)) {
      final glow = reduced ? 1.0 : 0.55 + 0.45 * math.sin(_time * 8).abs();
      _strokePaint
        ..color = TilePalette.hint.withValues(alpha: glow)
        ..strokeWidth = math.max(3, s * 0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(face.inflate(s * 0.02), radius),
        _strokePaint,
      );
    }

    canvas.restore();
  }

  void _drawBackPattern(Canvas canvas, Rect face, TilePalette p) {
    final s = face.width;
    _strokePaint
      ..color = p.backPattern
      ..strokeWidth = math.max(1, s * 0.035);
    canvas.drawRRect(
      RRect.fromRectAndRadius(face.deflate(s * 0.14), Radius.circular(s * 0.1)),
      _strokePaint,
    );
    _paint.color = p.backPattern;
    final c = face.center;
    canvas.drawCircle(c, s * 0.07, _paint);
    final d = s * 0.17;
    canvas.drawCircle(c.translate(-d, 0), s * 0.035, _paint);
    canvas.drawCircle(c.translate(d, 0), s * 0.035, _paint);
    canvas.drawCircle(c.translate(0, -d), s * 0.035, _paint);
    canvas.drawCircle(c.translate(0, d), s * 0.035, _paint);
  }

  /// Small corner badge: a check for matches, an X for mismatches, so state
  /// is never communicated by colour alone.
  void _drawBadge(Canvas canvas, double s, Color color, {required bool check}) {
    final r = s * 0.15;
    final c = Offset(s - r * 0.9, r * 0.9);
    _paint.color = const Color(0xFFFFFFFF);
    canvas.drawCircle(c, r * 1.15, _paint);
    _paint.color = color;
    canvas.drawCircle(c, r, _paint);
    SymbolRenderer.paint(
      canvas,
      check ? GameSymbol.checkmark : GameSymbol.cross,
      Rect.fromCircle(center: c, radius: r * 0.75),
      const Color(0xFFFFFFFF),
    );
  }
}
