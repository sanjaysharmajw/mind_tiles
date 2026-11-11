import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/app_theme.dart';
import '../game/board/game_symbol.dart';
import '../game/board/symbol_renderer.dart';

/// Night-sky gradient with slowly drifting faint symbols.
/// Static when reduced motion is on.
class GameBackground extends StatefulWidget {
  const GameBackground({super.key, required this.child, this.animate = true});

  final Widget child;
  final bool animate;

  @override
  State<GameBackground> createState() => _GameBackgroundState();
}

class _GameBackgroundState extends State<GameBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = AppScope.of(context).reducedMotion(context);
    if (widget.animate && !reduced) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.violet, AppColors.purple, AppColors.night],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: _FloatingSymbolsPainter(_controller)),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _FloatingSymbolsPainter extends CustomPainter {
  _FloatingSymbolsPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;
  static final List<_Floater> _floaters = _make();

  static List<_Floater> _make() {
    final r = math.Random(42);
    const symbols = [
      GameSymbol.star,
      GameSymbol.heart,
      GameSymbol.hexagon,
      GameSymbol.circleOutline,
      GameSymbol.cross,
      GameSymbol.diceFive,
      GameSymbol.diamond,
      GameSymbol.plus,
    ];
    return List.generate(16, (i) {
      return _Floater(
        symbol: symbols[i % symbols.length],
        x: r.nextDouble(),
        y: r.nextDouble(),
        size: 18 + r.nextDouble() * 34,
        speed: 0.5 + r.nextDouble(),
        phase: r.nextDouble() * math.pi * 2,
        alpha: 0.05 + r.nextDouble() * 0.07,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    for (final f in _floaters) {
      final y = ((f.y - t * f.speed) % 1.0) * (size.height + 80) - 40;
      final x =
          f.x * size.width + math.sin(t * math.pi * 2 * f.speed + f.phase) * 18;
      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: f.size,
        height: f.size,
      );
      SymbolRenderer.paint(
        canvas,
        f.symbol,
        rect,
        AppColors.yellow.withValues(alpha: f.alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_FloatingSymbolsPainter oldDelegate) => false;
}

class _Floater {
  const _Floater({
    required this.symbol,
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.alpha,
  });
  final GameSymbol symbol;
  final double x, y, size, speed, phase, alpha;
}
