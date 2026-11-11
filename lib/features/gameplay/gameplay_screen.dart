import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/app_scope.dart';
import '../../app/navigation.dart';
import '../../data/player_data_controller.dart';
import '../../game/board/board_layout.dart';
import '../../game/board/tile_palette.dart';
import '../../game/game_config.dart';
import '../../game/game_state.dart';
import '../../game/symbol_match_game.dart';
import '../../game/systems/audio_manager.dart';
import '../../game/systems/haptics_manager.dart';
import '../../services/ads/ad_service.dart';
import '../../services/analytics/analytics_service.dart';
import '../../services/performance/performance_tracer.dart';
import '../../widgets/game_background.dart';
import '../../widgets/panels.dart';
import 'gameplay_hud.dart';
import 'pause_overlay.dart';

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key, required this.config, this.resume});

  final LevelConfig config;

  /// When set, the saved game is restored instead of starting fresh.
  final SessionSnapshot? resume;

  @override
  State<GameplayScreen> createState() => GameplayScreenState();
}

class GameplayScreenState extends State<GameplayScreen>
    with WidgetsBindingObserver {
  late AppServices _services;
  late GameSession _session;
  late SymbolMatchGame _game;
  bool _initialised = false;
  bool _pauseMenuOpen = false;
  bool _leaving = false;
  RecordOutcome? _outcome;
  PerfTrace? _trace;

  /// Exposed for tests and the accessibility overlay.
  GameSession get session => _session;
  bool get pauseMenuOpen => _pauseMenuOpen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) {
      _game.visuals = _visuals();
      return;
    }
    _initialised = true;
    _services = AppScope.of(context);
    final resume = widget.resume;
    final restored = resume == null ? null : GameSession.fromSnapshot(resume);
    _session = restored ?? _newSession(widget.config);
    _session.addEventListener(_onGameEvent);
    _game = SymbolMatchGame(session: _session, visuals: _visuals())
      // Playables must not react to page visibility; the SDK drives pausing.
      ..pauseWhenBackgrounded = !_services.isPlayables;
    _services.hostPaused.addListener(_onHostPauseChanged);
    _services.player.addListener(_onPlayerChanged);
    WidgetsBinding.instance.addObserver(this);
    _pauseMenuOpen = _session.isPaused;
    _startTrace();
    _services.analytics.log(AnalyticsEvent.levelStarted, {
      'mode': _session.config.mode.name,
      'difficulty': _session.config.difficulty.name,
      'level': _session.config.level ?? 0,
      'resumed': restored != null,
    });
  }

  GameSession _newSession(LevelConfig config) => GameSession(
    config: config,
    previewDuration:
        config.previewSeconds * _services.player.settings.preview.multiplier,
  );

  GameVisuals _visuals() => GameVisuals(
    palette: TilePalette.of(_services.player.settings.tileTheme),
    reducedMotion: _services.reducedMotion(context),
  );

  void _onPlayerChanged() {
    if (!mounted) return;
    _game.visuals = _visuals();
  }

  /// Performance trace covering one board, from open to result.
  void _startTrace() {
    final c = _session.config;
    _trace = _services.performance.start(
      'level_play',
      attributes: {
        'mode': c.mode.name,
        'difficulty': c.difficulty.name,
        'board': '${c.columns}x${c.rows}',
      },
    );
  }

  void _stopTrace(String outcome) {
    final t = _trace;
    if (t == null) return;
    _trace = null;
    t
      ..putAttribute('outcome', outcome)
      ..setMetric('moves', _session.moves)
      ..setMetric('pairs_matched', _session.matchedPairs)
      ..setMetric('play_ms', (_session.elapsedSeconds * 1000).round());
    t.stop();
  }

  @override
  void dispose() {
    _stopTrace('abandoned');
    WidgetsBinding.instance.removeObserver(this);
    _services.hostPaused.removeListener(_onHostPauseChanged);
    _services.player.removeListener(_onPlayerChanged);
    _session.removeEventListener(_onGameEvent);
    _session.dispose();
    super.dispose();
  }

  /// YouTube Playables onPause/onResume: halt everything (game loop,
  /// rendering, clock) and save; on resume the player sees the pause menu.
  void _onHostPauseChanged() {
    if (!mounted) return;
    if (_services.hostPaused.value) {
      _pauseForBackground();
      _game.pauseEngine();
    } else {
      _game.resumeEngine();
    }
  }

  void _pauseForBackground() {
    if (_session.isInProgress) {
      _session.pause();
      _saveSnapshot();
      if (mounted && !_pauseMenuOpen) setState(() => _pauseMenuOpen = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_services.isPlayables) return; // SDK onPause/onResume only
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _pauseForBackground();
      case AppLifecycleState.resumed:
        break; // stay paused until the player taps Resume
    }
  }

  void _saveSnapshot() {
    if (_session.isInProgress) {
      _services.player.saveSnapshot(_session.toSnapshot());
    }
  }

  void _onGameEvent(GameEvent e) {
    final audio = _services.audio;
    final haptics = _services.haptics;
    switch (e.type) {
      case GameEventType.tileRevealed:
        audio.play(Sfx.flip);
        haptics.trigger(HapticKind.tap);
      case GameEventType.match:
        audio.play(Sfx.match);
        haptics.trigger(HapticKind.match);
        _services.analytics.log(AnalyticsEvent.matchFound, {
          'pairs': _session.matchedPairs,
        });
        _announce(
          'Match! ${_session.matchedPairs} of ${_session.totalPairs} pairs',
        );
      case GameEventType.mismatch:
        audio.play(Sfx.flip);
        audio.play(Sfx.mismatch);
        haptics.trigger(HapticKind.mismatch);
        _announce('No match');
      case GameEventType.hint:
        audio.play(Sfx.hint);
      case GameEventType.won:
        audio.play(Sfx.victory);
        haptics.trigger(HapticKind.success);
        _recordResult();
      case GameEventType.lost:
        audio.play(Sfx.fail);
        haptics.trigger(HapticKind.failure);
        _recordResult();
      case GameEventType.resultsReady:
        _goToResults();
      default:
        break;
    }
  }

  void _announce(String message) {
    if (!mounted) return;
    final view = View.of(context);
    SemanticsService.sendAnnouncement(
      view,
      message,
      Directionality.of(context),
    );
  }

  void _recordResult() {
    final result = _session.result;
    if (result == null || _outcome != null) return;
    _outcome = _services.player.recordResult(result, now: _services.clock());
    _stopTrace(result.won ? 'won' : 'lost');
    _services.ads.onGameFinished();
    _services.analytics.log(
      result.won ? AnalyticsEvent.levelCompleted : AnalyticsEvent.levelFailed,
      {
        'mode': result.config.mode.name,
        'difficulty': result.config.difficulty.name,
        'level': result.config.level ?? 0,
        'moves': result.moves,
        'score': result.score,
      },
    );
    for (final a in _outcome!.newAchievements) {
      _services.analytics.log(AnalyticsEvent.achievementUnlocked, {
        'id': a.id.name,
      });
    }
  }

  void _goToResults() {
    final result = _session.result;
    if (!mounted || result == null || _leaving) return;
    _leaving = true;
    AppNavigator.toResults(
      context,
      result,
      _outcome ?? RecordOutcome.notRecorded,
    );
  }

  // ---- player actions ----

  void openPauseMenu() {
    if (_session.isFinished) return;
    _session.pause();
    _saveSnapshot();
    setState(() => _pauseMenuOpen = true);
  }

  void resumeGame() {
    setState(() => _pauseMenuOpen = false);
    _session.resume();
  }

  /// Starts a fresh board with the same rules.
  void restartGame() {
    final old = _session;
    _stopTrace('restarted'); // record the old board's metrics first
    old.removeEventListener(_onGameEvent);
    _services.player.clearSnapshot(old.sessionId);
    final next = _newSession(old.config.withNewSeed(_services.random));
    next.addEventListener(_onGameEvent);
    _game.attachSession(next);
    setState(() {
      _session = next;
      _pauseMenuOpen = false;
      _outcome = null;
    });
    old.dispose();
    _startTrace();
  }

  Future<void> confirmRestart() async {
    final ok = await confirmAction(
      context,
      title: 'Restart?',
      message: 'Your current progress on this board will be lost.',
      confirmLabel: 'RESTART',
    );
    if (ok && mounted) restartGame();
  }

  Future<void> confirmQuit() async {
    final ok = await confirmAction(
      context,
      title: 'Leave game?',
      message:
          'Your board is saved — use Continue on the home screen to pick up where you left off.',
      confirmLabel: 'LEAVE',
      cancelLabel: 'Stay',
    );
    if (ok && mounted) {
      _saveSnapshot();
      _leaving = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> requestHint() async {
    if (_session.useHint()) return;
    final remaining = _session.hintsRemaining;
    if (remaining != null && remaining == 0 && _services.ads.isRewardedReady) {
      _session.pause();
      final outcome = await _services.ads.showRewarded();
      if (!mounted) return;
      _session.resume();
      if (outcome == RewardOutcome.rewarded) {
        _session.grantBonusHint();
        _services.analytics.log(AnalyticsEvent.rewardClaimed, {
          'reward': 'hint',
        });
        _session.useHint();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _leaving) return;
        if (_pauseMenuOpen) {
          confirmQuit();
        } else {
          openPauseMenu();
        }
      },
      child: Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _session,
              builder: (context, _) => Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final landscape =
                          constraints.maxWidth > constraints.maxHeight * 1.15;
                      final hud = GameplayHud(
                        session: _session,
                        landscape: landscape,
                        rewardedAvailable: _services.ads.isRewardedReady,
                        onPause: openPauseMenu,
                        onHint: requestHint,
                        onRestart: confirmRestart,
                      );
                      final board = _BoardArea(game: _game, session: _session);
                      if (landscape) {
                        return Row(
                          children: [
                            SizedBox(width: 230, child: hud),
                            Expanded(child: board),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          hud,
                          Expanded(child: board),
                        ],
                      );
                    },
                  ),
                  if (_session.isPreview) PreviewBanner(session: _session),
                  if (_pauseMenuOpen)
                    PauseOverlay(
                      title:
                          _session.hasStarted &&
                              widget.resume != null &&
                              !_session.isPreview
                          ? 'Welcome back!'
                          : 'Paused',
                      session: _session,
                      onResume: resumeGame,
                      onRestart: confirmRestart,
                      onQuit: confirmQuit,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sizes the Flame canvas from [BoardLayout] and scrolls large boards.
class _BoardArea extends StatelessWidget {
  const _BoardArea({required this.game, required this.session});

  final SymbolMatchGame game;
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final config = session.config;
        final available = Size(constraints.maxWidth, constraints.maxHeight);
        final layout = BoardLayout.fit(
          columns: config.columns,
          rows: config.rows,
          available: available,
        );
        final canvas = layout.canvasSize;
        final board = SizedBox(
          width: canvas.width,
          height: canvas.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  label:
                      'Game board, ${session.matchedPairs} of ${session.totalPairs} pairs matched',
                  child: GameWidget(game: game),
                ),
              ),
              _TileSemanticsOverlay(
                session: session,
                layout: layout,
                canvas: canvas,
              ),
            ],
          ),
        );
        if (layout.needsScroll(available.height)) {
          return SingleChildScrollView(
            key: const Key('board_scroll'),
            child: Center(child: board),
          );
        }
        return Center(child: board);
      },
    );
  }
}

/// Invisible semantics nodes over each tile so screen-reader users can
/// explore and select tiles. They do not intercept touches.
class _TileSemanticsOverlay extends StatelessWidget {
  const _TileSemanticsOverlay({
    required this.session,
    required this.layout,
    required this.canvas,
  });

  final GameSession session;
  final BoardLayout layout;
  final Size canvas;

  @override
  Widget build(BuildContext context) {
    final origin = layout.originIn(canvas);
    final cols = session.config.columns;
    return Stack(
      children: [
        for (final tile in session.board.tiles)
          Builder(
            builder: (context) {
              final r = layout.tileRect(tile.index, origin);
              final row = tile.index ~/ cols + 1;
              final col = tile.index % cols + 1;
              final state = tile.isMatched
                  ? 'matched ${tile.symbol.label}'
                  : session.isFaceUp(tile.index)
                  ? tile.symbol.label
                  : 'hidden';
              return Positioned.fromRect(
                rect: r,
                child: Semantics(
                  button: !tile.isMatched,
                  label: 'Row $row, column $col, $state',
                  onTap: tile.isMatched
                      ? null
                      : () => session.tapTile(tile.index),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
      ],
    );
  }
}
