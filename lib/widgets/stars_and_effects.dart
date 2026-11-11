import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../game/board/game_symbol.dart';
import 'symbol_icon.dart';

/// Row of up to three stars; [earned] are gold, the rest are outlines.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.earned,
    this.size = 20,
    this.max = 3,
  });

  final int earned;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$earned of $max stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < max; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.05),
              child: SymbolIcon(
                i < earned ? GameSymbol.star : GameSymbol.starOutline,
                size: size,
                color: i < earned ? AppColors.yellow : Colors.white38,
              ),
            ),
        ],
      ),
    );
  }
}

/// Stars that pop in one after another (results screen).
class AnimatedStars extends StatefulWidget {
  const AnimatedStars({
    super.key,
    required this.earned,
    this.size = 64,
    this.reducedMotion = false,
    this.onStarShown,
  });

  final int earned;
  final double size;
  final bool reducedMotion;
  final VoidCallback? onStarShown;

  @override
  State<AnimatedStars> createState() => _AnimatedStarsState();
}

class _AnimatedStarsState extends State<AnimatedStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  int _announced = 0;

  @override
  void initState() {
    super.initState();
    if (widget.reducedMotion) {
      _c.value = 1;
    } else {
      _c.addListener(_onTick);
      _c.forward();
    }
  }

  void _onTick() {
    final shown = (_c.value * 3 + 0.3).floor().clamp(0, widget.earned);
    while (_announced < shown) {
      _announced++;
      widget.onStarShown?.call();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.earned} of 3 stars earned',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [for (var i = 0; i < 3; i++) _star(i)],
        ),
      ),
    );
  }

  Widget _star(int i) {
    final start = i / 3;
    final t = ((_c.value - start) * 3).clamp(0.0, 1.0);
    final earned = i < widget.earned;
    final scale = earned ? Curves.elasticOut.transform(t) : 1.0;
    final s = i == 1 ? widget.size * 1.2 : widget.size;
    return Padding(
      padding: EdgeInsets.only(
        bottom: i == 1 ? s * 0.15 : 0,
        left: 4,
        right: 4,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SymbolIcon(GameSymbol.star, size: s, color: Colors.black26),
          Transform.scale(
            scale: earned ? scale : 0,
            child: SymbolIcon(
              GameSymbol.star,
              size: s,
              color: AppColors.yellow,
            ),
          ),
          SymbolIcon(
            GameSymbol.starOutline,
            size: s * 0.98,
            color: Colors.white54,
          ),
        ],
      ),
    );
  }
}

/// One-shot confetti burst painted over its child area.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.enabled = true});
  final bool enabled;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  late final List<_Confetto> _pieces;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    const colors = [
      AppColors.yellow,
      AppColors.coral,
      AppColors.teal,
      AppColors.sky,
      Colors.white,
      AppColors.orange,
    ];
    _pieces = List.generate(70, (i) {
      final angle = -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 0.9;
      return _Confetto(
        vx: math.cos(angle) * (0.3 + r.nextDouble() * 0.6),
        vy: math.sin(angle) * (0.9 + r.nextDouble() * 0.7),
        spin: (r.nextDouble() - 0.5) * 18,
        color: colors[i % colors.length],
        size: 6 + r.nextDouble() * 7,
      );
    });
    if (widget.enabled) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_c, _pieces),
        ),
      ),
    );
  }
}

class _Confetto {
  const _Confetto({
    required this.vx,
    required this.vy,
    required this.spin,
    required this.color,
    required this.size,
  });
  final double vx, vy, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim, this.pieces) : super(repaint: anim);
  final Animation<double> anim;
  final List<_Confetto> pieces;
  final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    if (t <= 0 || t >= 1) return;
    final origin = Offset(size.width / 2, size.height * 0.42);
    final scale = size.shortestSide;
    for (final c in pieces) {
      final x = origin.dx + c.vx * t * scale;
      final y = origin.dy + (c.vy * t + 1.6 * t * t) * scale * 0.6;
      _p.color = c.color.withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.spin * t);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: c.size,
          height: c.size * 0.55,
        ),
        _p,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => false;
}
