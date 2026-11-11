/// Static app metadata. Keep [version] in sync with `pubspec.yaml`
/// (a unit test enforces this).
class AppConfig {
  const AppConfig._();

  static const String appName = 'Mind Tiles';
  static const String version = '1.0.0';
  static const int buildNumber = 1;
  static const String fullVersion = '$version+$buildNumber';
}
