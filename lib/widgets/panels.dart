import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import 'game_background.dart';
import 'game_button.dart';

/// Cream "card" used for dialogs, stats and lists.
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = AppColors.panel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.panelBorder, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
        child: child,
      ),
    );
  }
}

/// Standard screen: background, safe area, header with back button + title.
class GameScreenScaffold extends StatelessWidget {
  const GameScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.onBack,
  });

  final String title;
  final Widget body;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: 'Back',
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.display(28).copyWith(
                            shadows: const [
                              Shadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centers content and caps its width on tablets / landscape.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 560});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Outlined display text (white with dark stroke) for big titles.
class OutlinedTitle extends StatelessWidget {
  const OutlinedTitle(
    this.text, {
    super.key,
    this.size = 48,
    this.color = Colors.white,
    this.stroke = AppColors.ink,
  });

  final String text;
  final double size;
  final Color color;
  final Color stroke;

  @override
  Widget build(BuildContext context) {
    final strokeStyle = AppTheme.display(size).copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.14
        ..strokeJoin = StrokeJoin.round
        ..color = stroke,
      color: null,
    );
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          children: [
            Text(text, textAlign: TextAlign.center, style: strokeStyle),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTheme.display(size, color: color).copyWith(
                shadows: [
                  Shadow(color: stroke, offset: Offset(0, size * 0.08)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a modal game-styled dialog.
Future<T?> showGameDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  required List<Widget> actions,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
    barrierColor: const Color(0xAA0D0620),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              type: MaterialType.transparency,
              child: GamePanel(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTheme.display(28, color: AppColors.ink),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (content != null) ...[
                      const SizedBox(height: 14),
                      content,
                    ],
                    const SizedBox(height: 18),
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      actions[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Yes/No confirmation for destructive actions. Resolves to true on confirm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) async {
  final result = await showGameDialog<bool>(
    context: context,
    title: title,
    message: message,
    actions: [
      Builder(
        builder: (ctx) => ChunkyButton.styled(
          ChunkyButton.coral,
          label: confirmLabel,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ),
      Builder(
        builder: (ctx) => ChunkyButton.styled(
          ChunkyButton.grey,
          label: cancelLabel,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ),
    ],
  );
  return result ?? false;
}
