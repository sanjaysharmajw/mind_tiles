import '../game/board/tile_palette.dart';

enum PreviewSetting {
  off(0.0, 'Off'),
  short(0.6, 'Short'),
  normal(1.0, 'Normal'),
  long(1.5, 'Long');

  const PreviewSetting(this.multiplier, this.label);
  final double multiplier;
  final String label;

  static PreviewSetting parse(Object? v) => PreviewSetting.values.firstWhere(
    (p) => p.name == v,
    orElse: () => PreviewSetting.normal,
  );
}

/// Player preferences. Immutable; update with [copyWith].
class GameSettings {
  const GameSettings({
    this.soundOn = true,
    this.musicOn = true,
    this.hapticsOn = true,
    this.reducedMotion = false,
    this.preview = PreviewSetting.normal,
    this.tileTheme = TileThemeId.classic,
    this.notificationsOn = false,
    this.analyticsOn = true,
  });

  final bool soundOn;
  final bool musicOn;
  final bool hapticsOn;
  final bool reducedMotion;
  final PreviewSetting preview;
  final TileThemeId tileTheme;

  /// Daily-challenge push reminders. Off until the player opts in, so the OS
  /// permission prompt is only shown in response to a deliberate action.
  final bool notificationsOn;

  /// Usage analytics, crash reports and performance traces (Firebase).
  final bool analyticsOn;

  GameSettings copyWith({
    bool? soundOn,
    bool? musicOn,
    bool? hapticsOn,
    bool? reducedMotion,
    PreviewSetting? preview,
    TileThemeId? tileTheme,
    bool? notificationsOn,
    bool? analyticsOn,
  }) => GameSettings(
    soundOn: soundOn ?? this.soundOn,
    musicOn: musicOn ?? this.musicOn,
    hapticsOn: hapticsOn ?? this.hapticsOn,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    preview: preview ?? this.preview,
    tileTheme: tileTheme ?? this.tileTheme,
    notificationsOn: notificationsOn ?? this.notificationsOn,
    analyticsOn: analyticsOn ?? this.analyticsOn,
  );

  Map<String, Object?> toJson() => {
    'soundOn': soundOn,
    'musicOn': musicOn,
    'hapticsOn': hapticsOn,
    'reducedMotion': reducedMotion,
    'preview': preview.name,
    'tileTheme': tileTheme.name,
    'notificationsOn': notificationsOn,
    'analyticsOn': analyticsOn,
  };

  /// Tolerant parser: any missing or malformed field falls back to default.
  factory GameSettings.fromJson(Object? json) {
    if (json is! Map) return const GameSettings();
    bool b(String k, bool d) => json[k] is bool ? json[k] as bool : d;
    return GameSettings(
      soundOn: b('soundOn', true),
      musicOn: b('musicOn', true),
      hapticsOn: b('hapticsOn', true),
      reducedMotion: b('reducedMotion', false),
      preview: PreviewSetting.parse(json['preview']),
      tileTheme: TileThemeId.parse(json['tileTheme']),
      notificationsOn: b('notificationsOn', false),
      analyticsOn: b('analyticsOn', true),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameSettings &&
      other.soundOn == soundOn &&
      other.musicOn == musicOn &&
      other.hapticsOn == hapticsOn &&
      other.reducedMotion == reducedMotion &&
      other.preview == preview &&
      other.tileTheme == tileTheme &&
      other.notificationsOn == notificationsOn &&
      other.analyticsOn == analyticsOn;

  @override
  int get hashCode => Object.hash(
    soundOn,
    musicOn,
    hapticsOn,
    reducedMotion,
    preview,
    tileTheme,
    notificationsOn,
    analyticsOn,
  );
}
