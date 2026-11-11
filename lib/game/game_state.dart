import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/game_result.dart';
import 'board/board_controller.dart';
import 'board/deck_generator.dart';
import 'board/game_symbol.dart';
import 'game_config.dart';
import 'modes/game_mode.dart';
import 'systems/game_timer.dart';
import 'systems/scoring_system.dart';
import 'systems/seeded_random.dart';

enum SessionStatus { preview, playing, paused, won, lost }

enum GameEventType {
  tileRevealed,
  match,
  mismatch,
  mismatchResolved,
  hint,
  previewEnded,
  paused,
  resumed,
  won,
  lost,

  /// Fired once, a moment after [won]/[lost], when the results should show.
  resultsReady,
}

class GameEvent {
  const GameEvent(this.type, [this.tiles = const []]);
  final GameEventType type;
  final List<int> tiles;
  @override
  String toString() => 'GameEvent(${type.name}, $tiles)';
}

typedef GameEventListener = void Function(GameEvent event);

/// Owns everything about one game in progress: the board rules, mode rules,
/// timers and the final result. Rendering (Flame) and UI (Flutter) only read
/// from it and forward input to it.
class GameSession extends ChangeNotifier {
  GameSession({
    required this.config,
    required double previewDuration,
    String? sessionId,
    this.mismatchDelay = 0.8,
    this.hintDuration = 1.6,
    this.resultsDelay = 1.4,
  }) : rules = GameModeRules.of(config.mode),
       board = BoardController(
         DeckGenerator.generate(
           pairs: config.pairs,
           random: SeededRandom(config.seed),
           maxTier: config.symbolTier,
           columns: config.columns,
         ),
       ),
       sessionId = sessionId ?? _newSessionId(config) {
    _startPreview(previewDuration);
  }

  GameSession._restored({
    required this.config,
    required this.board,
    required this.sessionId,
    required double elapsed,
    required this.hintsUsed,
    required this.bonusHints,
  }) : rules = GameModeRules.of(config.mode),
       mismatchDelay = 0.8,
       hintDuration = 1.6,
       resultsDelay = 1.4 {
    _elapsed = elapsed;
    _status = SessionStatus.paused;
    _resumeStatus = SessionStatus.playing;
  }

  /// Rebuilds a session from a snapshot. It starts paused so the player can
  /// get their bearings. Returns null for unusable snapshots.
  static GameSession? fromSnapshot(SessionSnapshot s) {
    try {
      final board = BoardController(s.deck);
      board.restore(
        matchedIndices: s.matched,
        moves: s.moves,
        mismatches: s.mismatches,
        combo: s.combo,
        bestCombo: s.bestCombo,
      );
      if (board.isComplete || board.tiles.length != s.config.tileCount) {
        return null;
      }
      return GameSession._restored(
        config: s.config,
        board: board,
        sessionId: s.sessionId,
        elapsed: s.elapsedSeconds.clamp(0, 24 * 3600).toDouble(),
        hintsUsed: max(0, s.hintsUsed),
        bonusHints: max(0, s.bonusHints),
      );
    } catch (_) {
      return null;
    }
  }

  static String _newSessionId(LevelConfig c) =>
      '${DateTime.now().microsecondsSinceEpoch}-${c.seed}';

  final LevelConfig config;
  final GameModeRules rules;
  final BoardController board;
  final String sessionId;
  final double mismatchDelay;
  final double hintDuration;
  final double resultsDelay;

  SessionStatus _status = SessionStatus.preview;
  SessionStatus _resumeStatus = SessionStatus.playing;
  final PhaseTimer _previewTimer = PhaseTimer();
  final PhaseTimer _mismatchTimer = PhaseTimer();
  final PhaseTimer _hintTimer = PhaseTimer();
  final PhaseTimer _resultsTimer = PhaseTimer();
  double _elapsed = 0;
  int hintsUsed = 0;
  int bonusHints = 0;
  List<int> _hintPair = const [];
  GameResult? _result;
  bool _resultsAnnounced = false;
  bool _disposed = false;
  int _lastNotifiedSecond = -1;
  final List<GameEventListener> _eventListeners = [];

  SessionStatus get status => _status;
  bool get isPreview => _status == SessionStatus.preview;
  bool get isPlaying => _status == SessionStatus.playing;
  bool get isPaused => _status == SessionStatus.paused;
  bool get isFinished =>
      _status == SessionStatus.won || _status == SessionStatus.lost;
  bool get isInProgress => !isFinished;
  bool get acceptsInput => isPlaying && !board.isResolving;
  double get previewRemaining => _previewTimer.remaining;
  double get elapsedSeconds => _elapsed;
  int get moves => board.moves;
  int get matchedPairs => board.matchedPairs;
  int get totalPairs => board.totalPairs;
  GameResult? get result => _result;
  bool get hasStarted => board.moves > 0 || board.firstIndex != null;

  double? get timeRemaining {
    final limit = config.timeLimitSeconds;
    return limit == null ? null : max(0.0, limit - _elapsed);
  }

  int? get movesRemaining {
    final limit = config.moveLimit;
    return limit == null ? null : max(0, limit - board.moves);
  }

  /// `null` = unlimited.
  int? get hintsRemaining {
    final allowance = config.hintAllowance;
    return allowance == null
        ? null
        : max(0, allowance + bonusHints - hintsUsed);
  }

  bool get canUseHint =>
      acceptsInput &&
      (hintsRemaining == null || hintsRemaining! > 0) &&
      !_hintTimer.isActive;

  /// Whether tile [i] should currently show its symbol.
  bool isFaceUp(int i) {
    final tile = board.tiles[i];
    if (tile.isMatched) return true;
    if (_status == SessionStatus.paused) {
      return false; // no peeking while paused
    }
    if (_status == SessionStatus.preview) return true;
    return tile.isRevealed;
  }

  bool isHinted(int i) => _hintTimer.isActive && _hintPair.contains(i);
  bool isMismatched(int i) => board.pendingMismatch.contains(i);

  void addEventListener(GameEventListener l) => _eventListeners.add(l);
  void removeEventListener(GameEventListener l) => _eventListeners.remove(l);

  void _emit(GameEvent e) {
    for (final l in List.of(_eventListeners)) {
      l(e);
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _startPreview(double seconds) {
    if (seconds <= 0) {
      _status = SessionStatus.playing;
    } else {
      _status = SessionStatus.preview;
      _previewTimer.start(seconds);
    }
  }

  /// Ends the memorisation preview early.
  void skipPreview() {
    if (_status != SessionStatus.preview) return;
    _previewTimer.cancel();
    _status = SessionStatus.playing;
    _emit(const GameEvent(GameEventType.previewEnded));
    _changed();
  }

  /// Handles a tap on tile [index].
  SelectionResult tapTile(int index) {
    if (_disposed || _status != SessionStatus.playing) {
      return SelectionResult.ignoredBusy;
    }
    final r = board.select(index);
    switch (r) {
      case SelectionResult.firstRevealed:
        _emit(GameEvent(GameEventType.tileRevealed, [index]));
      case SelectionResult.matched:
      case SelectionResult.completed:
        _hintTimer.cancel();
        final partner = board.tiles
            .firstWhere(
              (t) => t.index != index && t.symbol == board.tiles[index].symbol,
            )
            .index;
        _emit(GameEvent(GameEventType.match, [partner, index]));
      case SelectionResult.mismatched:
        _mismatchTimer.start(mismatchDelay);
        _emit(GameEvent(GameEventType.mismatch, board.pendingMismatch));
      default:
        return r;
    }
    if (r == SelectionResult.completed) {
      _finish(won: true);
    } else if (r.isMoveEnd) {
      final failure = rules.checkFailure(config, _progress());
      if (failure != null) _finish(won: false, reason: failure);
    }
    _changed();
    return r;
  }

  bool useHint() {
    if (!canUseHint) return false;
    final pair = board.findHintPair();
    if (pair == null) return false;
    hintsUsed++;
    _hintPair = pair;
    _hintTimer.start(hintDuration);
    _emit(GameEvent(GameEventType.hint, pair));
    _changed();
    return true;
  }

  /// Grants an extra hint (e.g. after a verified rewarded ad).
  void grantBonusHint() {
    bonusHints++;
    _changed();
  }

  void pause() {
    if (_status != SessionStatus.preview && _status != SessionStatus.playing) {
      return;
    }
    _resumeStatus = _status;
    _status = SessionStatus.paused;
    _emit(const GameEvent(GameEventType.paused));
    _changed();
  }

  void resume() {
    if (_status != SessionStatus.paused) return;
    _status = _resumeStatus;
    _emit(const GameEvent(GameEventType.resumed));
    _changed();
  }

  /// Advances all timers by [dt] seconds. (The Flame game clamps long frame
  /// gaps before calling this, so a stalled frame never eats the clock.)
  void tick(double dt) {
    if (_disposed || dt <= 0) return;
    final step = dt;
    switch (_status) {
      case SessionStatus.paused:
        return;
      case SessionStatus.preview:
        if (_previewTimer.tick(step)) {
          _status = SessionStatus.playing;
          _emit(const GameEvent(GameEventType.previewEnded));
          _changed();
        } else {
          _notifyOnSecond(_previewTimer.remaining);
        }
      case SessionStatus.playing:
        _elapsed += step;
        if (_hintTimer.tick(step)) {
          _hintPair = const [];
          _changed();
        }
        if (_mismatchTimer.tick(step)) {
          final tiles = board.pendingMismatch;
          board.resolveMismatch();
          _emit(GameEvent(GameEventType.mismatchResolved, tiles));
          _changed();
        }
        final failure = rules.checkFailure(config, _progress());
        if (failure != null) {
          _finish(won: false, reason: failure);
          _changed();
        } else {
          _notifyOnSecond(timeRemaining ?? _elapsed);
        }
      case SessionStatus.won:
      case SessionStatus.lost:
        _mismatchTimer.tick(step);
        if (_resultsTimer.tick(step) && !_resultsAnnounced) {
          _resultsAnnounced = true;
          _emit(const GameEvent(GameEventType.resultsReady));
        }
    }
  }

  void _notifyOnSecond(double seconds) {
    final s = seconds.floor();
    if (s != _lastNotifiedSecond) {
      _lastNotifiedSecond = s;
      _changed();
    }
  }

  ModeProgress _progress() => ModeProgress(
    elapsedSeconds: _elapsed,
    moves: board.moves,
    isComplete: board.isComplete,
  );

  void _finish({required bool won, FailureReason? reason}) {
    if (_result != null) return; // completion is reported exactly once
    _hintTimer.cancel();
    _previewTimer.cancel();
    if (won) {
      final score = ScoringSystem.calculate(
        ScoreInput(
          config: config,
          moves: board.moves,
          elapsedSeconds: _elapsed,
          bestCombo: board.bestCombo,
          hintsUsed: hintsUsed,
        ),
      );
      _result = GameResult(
        sessionId: sessionId,
        config: config,
        won: true,
        score: score.total,
        stars: score.stars,
        moves: board.moves,
        elapsedSeconds: _elapsed,
        accuracy: score.accuracy,
        matchedPairs: board.matchedPairs,
        bestCombo: board.bestCombo,
        hintsUsed: hintsUsed,
        timeRemaining: timeRemaining,
        movesRemaining: movesRemaining,
      );
      _status = SessionStatus.won;
      _emit(const GameEvent(GameEventType.won));
    } else {
      _result = GameResult(
        sessionId: sessionId,
        config: config,
        won: false,
        failureReason: reason,
        score: 0,
        stars: 0,
        moves: board.moves,
        elapsedSeconds: _elapsed,
        accuracy: ScoringSystem.accuracy(board.matchedPairs, board.moves),
        matchedPairs: board.matchedPairs,
        bestCombo: board.bestCombo,
        hintsUsed: hintsUsed,
        timeRemaining: timeRemaining,
        movesRemaining: movesRemaining,
      );
      _status = SessionStatus.lost;
      _emit(const GameEvent(GameEventType.lost));
    }
    _resultsTimer.start(resultsDelay);
  }

  SessionSnapshot toSnapshot() => SessionSnapshot(
    config: config,
    deck: [for (final t in board.tiles) t.symbol],
    matched: {
      for (final t in board.tiles)
        if (t.isMatched) t.index,
    },
    moves: board.moves,
    mismatches: board.mismatches,
    combo: board.combo,
    bestCombo: board.bestCombo,
    hintsUsed: hintsUsed,
    bonusHints: bonusHints,
    elapsedSeconds: _elapsed,
    sessionId: sessionId,
    savedAt: DateTime.now(),
  );

  @override
  void dispose() {
    _disposed = true;
    _eventListeners.clear();
    super.dispose();
  }
}

/// Serializable copy of an in-progress game, used by "Continue".
class SessionSnapshot {
  const SessionSnapshot({
    required this.config,
    required this.deck,
    required this.matched,
    required this.moves,
    required this.mismatches,
    required this.combo,
    required this.bestCombo,
    required this.hintsUsed,
    required this.bonusHints,
    required this.elapsedSeconds,
    required this.sessionId,
    required this.savedAt,
  });

  final LevelConfig config;
  final List<GameSymbol> deck;
  final Set<int> matched;
  final int moves;
  final int mismatches;
  final int combo;
  final int bestCombo;
  final int hintsUsed;
  final int bonusHints;
  final double elapsedSeconds;
  final String sessionId;
  final DateTime savedAt;

  Map<String, Object?> toJson() => {
    'config': config.toJson(),
    'deck': [for (final s in deck) s.name],
    'matched': matched.toList()..sort(),
    'moves': moves,
    'mismatches': mismatches,
    'combo': combo,
    'bestCombo': bestCombo,
    'hintsUsed': hintsUsed,
    'bonusHints': bonusHints,
    'elapsed': elapsedSeconds,
    'sessionId': sessionId,
    'savedAt': savedAt.toIso8601String(),
  };

  static SessionSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final config = LevelConfig.fromJson(json['config']);
      if (config == null) return null;
      final deck = <GameSymbol>[];
      for (final n in json['deck'] as List) {
        final s = GameSymbol.tryParse(n as String);
        if (s == null) return null;
        deck.add(s);
      }
      if (deck.length != config.tileCount || !DeckGenerator.isValid(deck)) {
        return null;
      }
      return SessionSnapshot(
        config: config,
        deck: deck,
        matched: {
          for (final i in json['matched'] as List)
            if (i is int && i >= 0 && i < deck.length) i,
        },
        moves: json['moves'] as int,
        mismatches: (json['mismatches'] as int?) ?? 0,
        combo: (json['combo'] as int?) ?? 0,
        bestCombo: (json['bestCombo'] as int?) ?? 0,
        hintsUsed: (json['hintsUsed'] as int?) ?? 0,
        bonusHints: (json['bonusHints'] as int?) ?? 0,
        elapsedSeconds: (json['elapsed'] as num).toDouble(),
        sessionId: json['sessionId'] as String,
        savedAt:
            DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
