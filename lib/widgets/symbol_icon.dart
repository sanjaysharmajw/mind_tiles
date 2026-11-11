import 'package:flutter/material.dart';

import '../game/board/game_symbol.dart';
import '../game/board/symbol_renderer.dart';

/// Draws a [GameSymbol] as a Flutter widget (same vector paths as the board).
class SymbolIcon extends StatelessWidget {
  const SymbolIcon(
    this.symbol, {
    super.key,
    this.size = 24,
    this.color = Colors.black,
  });

  final GameSymbol symbol;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _SymbolPainter(symbol, color),
    ),
  );
}

class _SymbolPainter extends CustomPainter {
  _SymbolPainter(this.symbol, this.color);
  final GameSymbol symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      SymbolRenderer.paint(canvas, symbol, Offset.zero & size, color);

  @override
  bool shouldRepaint(_SymbolPainter old) =>
      old.symbol != symbol || old.color != color;
}

/// A small static yellow tile with a symbol, used in menus and the logo.
class MiniTile extends StatelessWidget {
  const MiniTile({
    super.key,
    required this.symbol,
    this.size = 44,
    this.faceColor = const Color(0xFFFFD43B),
    this.edgeColor = const Color(0xFFCF8E00),
    this.symbolColor = const Color(0xFF1C1917),
    this.faceDown = false,
  });

  final GameSymbol symbol;
  final double size;
  final Color faceColor;
  final Color edgeColor;
  final Color symbolColor;
  final bool faceDown;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.2);
    final face = faceDown ? const Color(0xFFFF7A45) : faceColor;
    final edge = faceDown ? const Color(0xFFB33A12) : edgeColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: edge,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: size,
          height: size * 0.93,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(face, Colors.white, 0.25)!, face],
            ),
          ),
          alignment: Alignment.center,
          child: faceDown
              ? Container(
                  width: size * 0.2,
                  height: size * 0.2,
                  decoration: const BoxDecoration(
                    color: Color(0x66FFFFFF),
                    shape: BoxShape.circle,
                  ),
                )
              : SymbolIcon(symbol, size: size * 0.6, color: symbolColor),
        ),
      ),
    );
  }
}
