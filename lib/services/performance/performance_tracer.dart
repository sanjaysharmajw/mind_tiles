/// A running custom performance trace (e.g. one game session).
abstract class PerfTrace {
  void setMetric(String name, int value);
  void putAttribute(String name, String value);
  Future<void> stop();
}

/// Performance monitoring abstraction (Firebase Performance in production).
abstract class PerformanceTracer {
  const PerformanceTracer();

  /// Starts a trace. Never throws; returns a no-op trace on failure.
  PerfTrace start(String name, {Map<String, String> attributes = const {}});

  void setEnabled(bool enabled) {}
}

class NoopPerformanceTracer extends PerformanceTracer {
  const NoopPerformanceTracer();

  @override
  PerfTrace start(String name, {Map<String, String> attributes = const {}}) =>
      NoopTrace();
}

class NoopTrace implements PerfTrace {
  final Map<String, int> metrics = {};
  final Map<String, String> attributes = {};
  bool stopped = false;

  @override
  void setMetric(String name, int value) => metrics[name] = value;
  @override
  void putAttribute(String name, String value) => attributes[name] = value;
  @override
  Future<void> stop() async => stopped = true;
}
