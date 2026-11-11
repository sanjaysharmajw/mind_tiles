import 'package:flutter/material.dart';

import '../features/daily/daily_screen.dart';
import '../features/home/home_screen.dart';
import '../services/notifications/push_service.dart';
import 'app_config.dart';
import 'app_scope.dart';
import 'app_theme.dart';

class MindTilesApp extends StatefulWidget {
  const MindTilesApp({super.key, required this.services});

  final AppServices services;

  @override
  State<MindTilesApp> createState() => _MindTilesAppState();
}

class _MindTilesAppState extends State<MindTilesApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final List<NavigatorObserver> _observers = [
    ?widget.services.analytics.navigatorObserver,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.services.player.addListener(_onPlayerChanged);
    widget.services.push.onOpen = _openFromNotification;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.services.player.removeListener(_onPlayerChanged);
    widget.services.push.onOpen = null;
    super.dispose();
  }

  /// A tapped notification with `screen: daily` opens the Daily Challenge
  /// (unless a game is in progress — never interrupt play).
  void _openFromNotification(PushTarget target) {
    if (target != PushTarget.daily) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navigatorKey.currentState;
      if (nav == null) return;
      var inGame = false;
      nav.popUntil((r) {
        inGame = inGame || r.settings.name == 'gameplay';
        return true;
      });
      if (inGame) return;
      nav.popUntil((r) => r.isFirst);
      nav.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'daily'),
          builder: (_) => const DailyScreen(),
        ),
      );
    });
  }

  void _onPlayerChanged() => widget.services.syncSettings();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Playables: pause/resume come only from the YouTube SDK (onPause /
    // onResume); the web Page Visibility signal must not be used.
    if (widget.services.isPlayables) return;
    final active = state == AppLifecycleState.resumed;
    widget.services.audio.setAppActive(active);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.services.player.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: MaterialApp(
        title: AppConfig.appName,
        navigatorKey: _navigatorKey,
        navigatorObservers: _observers,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(bundledFontsOnly: widget.services.isPlayables),
        // Respect the user's text size, within limits the layouts support.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
          // While the host has paused the game, stop every ticker so no
          // animation, timer or rendering keeps running.
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.services.hostPaused,
            builder: (context, paused, child) =>
                TickerMode(enabled: !paused, child: child!),
            child: child,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
