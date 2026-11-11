import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_theme.dart';
import '../../game/board/game_symbol.dart';
import '../../services/analytics/analytics_service.dart';
import '../../widgets/game_background.dart';
import '../../widgets/game_button.dart';
import '../../widgets/panels.dart';
import '../../widgets/stars_and_effects.dart';
import '../../widgets/symbol_icon.dart';

/// Four short pages explaining the rules. Pops `true` when finished.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const _count = 4;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish({required bool completed}) {
    final services = AppScope.of(context);
    services.player.markTutorialSeen();
    if (completed) services.analytics.log(AnalyticsEvent.tutorialCompleted);
    Navigator.of(context).pop(completed);
  }

  void _next() {
    if (_index == _count - 1) {
      _finish(completed: true);
      return;
    }
    final reduced = AppScope.of(context).reducedMotion(context);
    if (reduced) {
      _pages.jumpToPage(_index + 1);
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _TutorialPage(
        title: 'Memorize',
        text:
            'Every board starts with a short peek at all the tiles. Remember where the symbols are!',
        art: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in const [
              GameSymbol.star,
              GameSymbol.heart,
              GameSymbol.hexagon,
              GameSymbol.cross,
              GameSymbol.heart,
              GameSymbol.star,
            ])
              MiniTile(symbol: s, size: 56),
          ],
        ),
      ),
      const _TutorialPage(
        title: 'Flip two tiles',
        text:
            'Then the tiles turn face down. Tap a tile to flip it, then tap a second one. '
            'Each pair of flips is one move.',
        art: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MiniTile(symbol: GameSymbol.circleOutline, size: 72),
            SizedBox(width: 10),
            MiniTile(symbol: GameSymbol.star, size: 72, faceDown: true),
          ],
        ),
      ),
      _TutorialPage(
        title: 'Make matches',
        text:
            'Same symbols? They stay up with a green check badge. Different? They show a red cross and flip back — '
            'remember them for later!',
        art: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _badged(GameSymbol.heart, ok: true),
            const SizedBox(width: 8),
            _badged(GameSymbol.heart, ok: true),
            const SizedBox(width: 22),
            _badged(GameSymbol.hexagon, ok: false),
            const SizedBox(width: 8),
            _badged(GameSymbol.diceFive, ok: false),
          ],
        ),
      ),
      const _TutorialPage(
        title: 'Stars & modes',
        text:
            'Fewer moves earn more stars. Stuck? Tap the light-bulb for a hint. Try Timed, Limited Moves and '
            'the Daily Challenge once you get the hang of it.',
        art: StarRow(earned: 3, size: 64),
      ),
    ];

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('tutorial_skip'),
                  onPressed: () => _finish(completed: false),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: pages,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      width: i == _index ? 24 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.yellow : Colors.white38,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: ContentWidth(
                  maxWidth: 420,
                  child: ChunkyButton(
                    key: const Key('tutorial_next'),
                    label: _index == _count - 1 ? "LET'S PLAY!" : 'NEXT',
                    onPressed: _next,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _badged(GameSymbol s, {required bool ok}) => Stack(
    clipBehavior: Clip.none,
    children: [
      MiniTile(symbol: s, size: 52),
      Positioned(
        right: -5,
        top: -5,
        child: CircleAvatar(
          radius: 11,
          backgroundColor: ok ? AppColors.success : AppColors.danger,
          child: Icon(
            ok ? Icons.check_rounded : Icons.close_rounded,
            size: 15,
            color: Colors.white,
          ),
        ),
      ),
    ],
  );
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({
    required this.title,
    required this.text,
    required this.art,
  });
  final String title;
  final String text;
  final Widget art;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ContentWidth(
        maxWidth: 440,
        child: Column(
          children: [
            const SizedBox(height: 12),
            SizedBox(height: 180, child: Center(child: art)),
            const SizedBox(height: 20),
            GamePanel(
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppTheme.display(30, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.35,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
