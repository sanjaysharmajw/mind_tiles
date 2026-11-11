import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/app_theme.dart';

/// Chunky casual-game button with a 3D bottom edge and press animation.
/// Plays the button sound/haptic (respecting settings) before [onPressed].
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.yellow,
    this.edgeColor = AppColors.yellowDark,
    this.textColor = AppColors.ink,
    this.icon,
    this.height = 58,
    this.fontSize = 22,
    this.expand = true,
    this.semanticLabel,
    this.silent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color edgeColor;
  final Color textColor;
  final IconData? icon;
  final double height;
  final double fontSize;
  final bool expand;
  final String? semanticLabel;

  /// Skip the default click sound (for buttons that play their own).
  final bool silent;

  static const ChunkyButtonStyle teal = (
    AppColors.teal,
    AppColors.tealDark,
    Colors.white,
  );
  static const ChunkyButtonStyle sky = (
    AppColors.sky,
    AppColors.skyDark,
    Colors.white,
  );
  static const ChunkyButtonStyle coral = (
    AppColors.coral,
    AppColors.coralDark,
    Colors.white,
  );
  static const ChunkyButtonStyle orange = (
    AppColors.orange,
    AppColors.orangeDark,
    Colors.white,
  );
  static const ChunkyButtonStyle grey = (
    AppColors.grey,
    AppColors.greyDark,
    Colors.white,
  );

  factory ChunkyButton.styled(
    ChunkyButtonStyle style, {
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    double height = 58,
    double fontSize = 22,
    bool expand = true,
    String? semanticLabel,
  }) => ChunkyButton(
    key: key,
    label: label,
    onPressed: onPressed,
    color: style.$1,
    edgeColor: style.$2,
    textColor: style.$3,
    icon: icon,
    height: height,
    fontSize: fontSize,
    expand: expand,
    semanticLabel: semanticLabel,
  );

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

typedef ChunkyButtonStyle = (Color, Color, Color);

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  void _set(bool v) {
    if (_enabled && _down != v) setState(() => _down = v);
  }

  void _activate() {
    if (!_enabled) return;
    if (!widget.silent) AppScope.of(context).buttonFeedback();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final edge = widget.height * 0.1;
    final face = _enabled ? widget.color : AppColors.grey;
    final edgeColor = _enabled ? widget.edgeColor : AppColors.greyDark;
    final textColor = _enabled ? widget.textColor : Colors.white70;
    final offset = _down ? edge * 0.8 : 0.0;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: textColor, size: widget.fontSize * 1.15),
          if (widget.label.isNotEmpty) const SizedBox(width: 8),
        ],
        if (widget.label.isNotEmpty)
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.display(widget.fontSize, color: textColor),
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      onTap: _enabled ? _activate : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) {
          _set(false);
          _activate();
        },
        child: SizedBox(
          height: widget.height + edge,
          child: Stack(
            children: [
              Positioned.fill(
                top: edge,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: edgeColor,
                    borderRadius: BorderRadius.circular(widget.height * 0.32),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              // The face is the only non-positioned child, so it decides the
              // button's width (fills when constrained, hugs content otherwise).
              AnimatedPadding(
                duration: const Duration(milliseconds: 70),
                padding: EdgeInsets.only(top: offset, bottom: edge - offset),
                child: Container(
                  height: widget.height,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.height * 0.32),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(face, Colors.white, 0.22)!, face],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular icon button used in headers and the HUD.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 48,
    this.color = AppColors.violet,
    this.iconColor = Colors.white,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final Color color;
  final Color iconColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Tooltip(
        message: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () {
                  AppScope.of(context).buttonFeedback();
                  onPressed!();
                }
              : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? color : AppColors.greyDark,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: enabled ? iconColor : Colors.white54,
                    size: size * 0.5,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.coral,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(badge!, style: AppTheme.display(12)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
