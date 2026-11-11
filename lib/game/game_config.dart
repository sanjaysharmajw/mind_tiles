import 'dart:math';

/// Which ruleset a game is played under.
enum GameModeType { classic, timed, limitedMoves, daily, practice }

enum Difficulty {
  easy('Easy', 1.0),
  medium('Medium', 1.5),
  hard('Hard', 2.0),
  expert('Expert', 2.5);

  const Difficulty(this.label, this.scoreMultiplier);
  final String label;
  final double scoreMultiplier;

  static Difficulty fromPairs(int pairs) {
    if (pairs <= 10) return Difficulty.easy;
    if (pairs <= 21) return Difficulty.medium;
    if (pairs <= 32) return Difficulty.hard;
    return Difficulty.expert;
  }

  static Difficulty parse(Object? v) => Difficulty.values.firstWhere(
    (d) => d.name == v,
    orElse: () => Difficulty.easy,
  );
}

/// Board dimensions used by the difficulty-based modes
/// (Timed, Limited Moves, Practice).
class BoardSpec {
  const BoardSpec(this.columns, this.rows);
  final int columns;
  final int rows;
  int get pairs => columns * rows ~/ 2;

  static BoardSpec forDifficulty(Difficulty d) => switch (d) {
    Difficulty.easy => const BoardSpec(4, 4),
    Difficulty.medium => const BoardSpec(6, 6),
    Difficulty.hard => const BoardSpec(8, 8),
    Difficulty.expert => const BoardSpec(8, 10),
  };

  static int symbolTierFor(Difficulty d) => switch (d) {
    Difficulty.easy => 1,
    Difficulty.medium => 2,
    Difficulty.hard => 3,
    Difficulty.expert => 3,
  };
}

/// Immutable description of a single game to be played.
class LevelConfig {
  const LevelConfig({
    required this.mode,
    required this.difficulty,
    required this.columns,
    required this.rows,
    required this.previewSeconds,
    required this.symbolTier,
    required this.seed,
    this.level,
    this.dateKey,
    this.timeLimitSeconds,
    this.moveLimit,
    this.hintAllowance,
  }) : assert(columns * rows % 2 == 0, 'board must have an even tile count');

  final GameModeType mode;
  final Difficulty difficulty;
  final int columns;
  final int rows;

  /// Base preview time before the player's preview setting is applied.
  final double previewSeconds;
  final int symbolTier;
  final int seed;

  /// Campaign level number (Classic mode only).
  final int? level;

  /// `yyyy-mm-dd` for the Daily Challenge.
  final String? dateKey;
  final int? timeLimitSeconds;
  final int? moveLimit;

  /// Hints available; `null` means unlimited.
  final int? hintAllowance;

  int get tileCount => columns * rows;
  int get pairs => tileCount ~/ 2;
  bool get hasTimeLimit => timeLimitSeconds != null;
  bool get hasMoveLimit => moveLimit != null;

  /// Identifier used for best-score records.
  String get recordKey => switch (mode) {
    GameModeType.classic => 'level_$level',
    GameModeType.daily => 'daily_$dateKey',
    _ => '${mode.name}_${difficulty.name}',
  };

  String get title => switch (mode) {
    GameModeType.classic => 'Level $level',
    GameModeType.timed => 'Timed · ${difficulty.label}',
    GameModeType.limitedMoves => 'Limited Moves · ${difficulty.label}',
    GameModeType.daily => 'Daily Challenge',
    GameModeType.practice => 'Practice · ${difficulty.label}',
  };

  LevelConfig withNewSeed(Random random) => mode == GameModeType.daily
      ? this
      : LevelConfig(
          mode: mode,
          difficulty: difficulty,
          columns: columns,
          rows: rows,
          previewSeconds: previewSeconds,
          symbolTier: symbolTier,
          seed: random.nextInt(1 << 31),
          level: level,
          dateKey: dateKey,
          timeLimitSeconds: timeLimitSeconds,
          moveLimit: moveLimit,
          hintAllowance: hintAllowance,
        );

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'difficulty': difficulty.name,
    'columns': columns,
    'rows': rows,
    'previewSeconds': previewSeconds,
    'symbolTier': symbolTier,
    'seed': seed,
    'level': level,
    'dateKey': dateKey,
    'timeLimitSeconds': timeLimitSeconds,
    'moveLimit': moveLimit,
    'hintAllowance': hintAllowance,
  };

  /// Returns null if [json] is not a usable config.
  static LevelConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final mode = GameModeType.values.firstWhere(
        (m) => m.name == json['mode'],
      );
      final columns = json['columns'] as int;
      final rows = json['rows'] as int;
      if (columns < 2 || rows < 2 || (columns * rows).isOdd) return null;
      return LevelConfig(
        mode: mode,
        difficulty: Difficulty.parse(json['difficulty']),
        columns: columns,
        rows: rows,
        previewSeconds: (json['previewSeconds'] as num).toDouble(),
        symbolTier: json['symbolTier'] as int,
        seed: json['seed'] as int,
        level: json['level'] as int?,
        dateKey: json['dateKey'] as String?,
        timeLimitSeconds: json['timeLimitSeconds'] as int?,
        moveLimit: json['moveLimit'] as int?,
        hintAllowance: json['hintAllowance'] as int?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LevelConfig &&
      other.mode == mode &&
      other.difficulty == difficulty &&
      other.columns == columns &&
      other.rows == rows &&
      other.previewSeconds == previewSeconds &&
      other.symbolTier == symbolTier &&
      other.seed == seed &&
      other.level == level &&
      other.dateKey == dateKey &&
      other.timeLimitSeconds == timeLimitSeconds &&
      other.moveLimit == moveLimit &&
      other.hintAllowance == hintAllowance;

  @override
  int get hashCode => Object.hash(
    mode,
    difficulty,
    columns,
    rows,
    previewSeconds,
    symbolTier,
    seed,
    level,
    dateKey,
    timeLimitSeconds,
    moveLimit,
    hintAllowance,
  );
}
